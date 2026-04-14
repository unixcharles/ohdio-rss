class EpisodeQueryFilter
  ParseError = Class.new(StandardError)

  OPERATOR_REGEX = /\b(?:AND|OR|NOT)\b/i

  def self.apply(scope, query, columns: nil)
    normalized = query.to_s.strip
    return scope if normalized.blank?

    predicate = new(scope.klass.arel_table, columns: columns).build_predicate(normalized)
    scope.where(predicate)
  end

  def initialize(table, columns: nil)
    @table = table
    @columns = Array(columns).presence || default_columns
  end

  def build_predicate(query)
    ast = parse(query)
    arel_for(ast)
  rescue ParseError
    term_predicate(query)
  end

  private

  def parse(query)
    @tokens = tokenize(query)
    @index = 0
    raise ParseError, "empty query" if @tokens.empty?

    expression = parse_or
    raise ParseError, "unexpected token" unless eof?

    expression
  end

  def tokenize(query)
    tokens = []
    cursor = 0

    query.to_enum(:scan, OPERATOR_REGEX).map { Regexp.last_match }.each do |match|
      leading = query[cursor...match.begin(0)].to_s.strip
      tokens << { type: :term, value: leading } if leading.present?
      tokens << { type: :operator, value: match[0].upcase }
      cursor = match.end(0)
    end

    trailing = query[cursor..].to_s.strip
    tokens << { type: :term, value: trailing } if trailing.present?
    tokens
  end

  def parse_or
    node = parse_and

    while consume_operator("OR")
      node = [ :or, node, parse_and ]
    end

    node
  end

  def parse_and
    node = parse_unary

    while consume_operator("AND")
      node = [ :and, node, parse_unary ]
    end

    node
  end

  def parse_unary
    if consume_operator("NOT")
      [ :not, parse_unary ]
    else
      parse_term
    end
  end

  def parse_term
    token = current_token
    raise ParseError, "missing term" unless token&.dig(:type) == :term

    @index += 1
    [ :term, token[:value] ]
  end

  def consume_operator(value)
    token = current_token
    return false unless token&.dig(:type) == :operator && token[:value] == value

    @index += 1
    true
  end

  def current_token
    @tokens[@index]
  end

  def eof?
    @index >= @tokens.size
  end

  def arel_for(node)
    kind = node[0]

    case kind
    when :term
      term_predicate(node[1])
    when :and
      arel_for(node[1]).and(arel_for(node[2]))
    when :or
      arel_for(node[1]).or(arel_for(node[2]))
    when :not
      arel_for(node[1]).not
    else
      raise ParseError, "unknown node"
    end
  end

  def term_predicate(term)
    normalized = term.to_s.strip.downcase
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(normalized)}%"

    predicates = @columns.filter_map do |column|
      next unless @table[column]

      empty = Arel::Nodes.build_quoted("")
      value = Arel::Nodes::NamedFunction.new("COALESCE", [ @table[column], empty ])
      lowered = Arel::Nodes::NamedFunction.new("LOWER", [ value ])
      lowered.matches(pattern)
    end

    return Arel.sql("1=0") if predicates.empty?

    predicates.reduce { |combined, predicate| combined.or(predicate) }
  end

  def default_columns
    [ :title, :description ]
  end
end

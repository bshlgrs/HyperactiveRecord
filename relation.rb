class Relation

  [:select_clause, :from_clause, :where_clauses].map do |clause|

    define_method("#{clause}=") do |value|
      set_instance_variable("@#{clause}", value)
      @value = nil
    end

    define_method("#{clause}") do
      @value = nil
      instance_variable_get("@#{clause}")
    end
  end

  def initialize(select_clause, from_clause, where_clauses, output_class)
    @select_clause = select_clause
    @from_clause = from_clause
    @where_clauses = where_clauses
    @output_class = output_class

    @value = nil
  end

  def render
    if where_clauses.length > 0
      "SELECT #{select_clause}
      FROM #{from_clause}
      WHERE #{where_clauses.join(' AND ')}"
    else
      "SELECT #{select_clause}
      FROM #{from_clause}"
    end
  end

  def value
    @value = @value || DBConnection.execute(render)

    @output_class.parse_all(@value)
  end

  def where(new_clause)
    out = self.dup
    out.where_clauses << new_clause
    out
  end

  def method_missing(meth, *args, &block)
    value.send(meth,*args,&block)
  end
end

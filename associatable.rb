require_relative './db_connection.rb'
require_relative './relation.rb'

class AssocParams
  def other_class
    @other_class
  end

  def other_table
    @other_class.table_name || @other_class.to_s.underscore.pluralize
  end
end

class BelongsToAssocParams < AssocParams
  attr_reader :name, :other_class_name, :primary_key, :foreign_key, :other_class

  def initialize(name, params)
    @name = name
    @other_class_name = (params[:class_name] || name).to_s.pluralize.underscore
    @primary_key = params[:primary_key] || "id"
    @foreign_key = params[:foreign_key] || "#{name}_id"
    @other_class = params[:other_class] || name.singularize.camelcase.constantize
  end

  def type
    @other_class
  end
end

class HasManyAssocParams < AssocParams
  attr_reader :name, :other_class_name, :primary_key, :foreign_key, :other_class

  def initialize(name, params, self_class)
    @name = name
    @other_class_name = params[:class_name] || name.to_s.pluralize.underscore
    @primary_key = params[:primary_key] || "id"
    @foreign_key = params[:foreign_key] || "#{self_class.underscore}_id"
    @other_class = params[:other_class] || name.to_s.singularize.camelcase.constantize
  end

  def type
    @other_class
  end
end

module Associatable

  def assoc_params
    if @assoc_params.nil?
      @assoc_params = {}
    end
    @assoc_params
  end

  def belongs_to(name, **params)
    define_method(name) do
      aps = BelongsToAssocParams.new(name.to_s, params)

      self.class.assoc_params[name] = aps

      foreign_key = send(aps.foreign_key)

      relation = Relation.new(
        "*", aps.other_table, ["#{aps.primary_key} = #{foreign_key}"], aps.other_class)

      results = relation.value

      if results.length == 1
        results.first
      else
        nil
      end
    end
  end

  def has_many(name, params)
    define_method(name) do
      aps = HasManyAssocParams.new(name.to_s, params, self.class.to_s)
      primary_key = self.send(aps.primary_key)

      relation = Relation.new(
        "*", aps.other_table, ["#{aps.foreign_key} = #{primary_key}"],
          aps.other_class)
    end
  end

  def has_one_through(name, assoc_name_1, assoc_name_2)
    define_method(name) do
      assoc1 = self.class.assoc_params[assoc_name_1]
      assoc2 = assoc1.other_class.assoc_params[assoc_name_2]

      relation = Relation.new(
        "#{assoc2.other_table}.*", "#{assoc1.other_table}
        JOIN #{assoc2.other_table}
        ON #{assoc1.other_table}.#{assoc2.foreign_key}
            = #{assoc2.other_table}.#{assoc2.primary_key}",
        ["#{assoc1.other_table}.#{assoc1.primary_key}
            = #{self.send(assoc1.primary_key)}"],
        assoc2.other_class)

      results = relation.value

      if results.length == 1
        results.first
      else
        nil
      end
    end
  end

  def has_many_through(name, assoc_name_1, assoc_name_2)
    assoc1 = self.class.assoc_params[assoc_name_1]
    assoc2 = assoc1.other_class.assoc_params[assoc_name_2]

    if (assoc1.is_a?(BelongsToAssocParams) && assoc2.is_a?(HasManyAssocParams))
      Relation.new("#{assoc2.other_table}.*",
              "#{assoc1.other_table}
        JOIN #{assoc2.other_table}
        ON #{assoc1.other_table}.#{assoc2.primary_key}
            = #{assoc2.other_table}.#{assoc2.foreign_key}",
            ["#{assoc1.other_table}.#{assoc1.primary_key}
            = #{self.send(assoc1.foreign_key)}",
            assoc2.other_class])

    elsif (assoc1.is_a?(HasManyAssocParams) && assoc2.is_a?(BelongsToAssocParams))
      Relation.new("#{assoc2.other_table}.*",
        "#{assoc1.other_table}
        JOIN #{assoc2.other_table}
        ON #{assoc1.other_table}.#{assoc2.foreign_key}
            = #{assoc2.other_table}.#{assoc2.primary_key}",
            ["#{assoc1.other_table}.#{assoc1.foreign_key}
            = #{self.send(assoc1.primary_key)}"],
            assoc2.other_class)

    elsif (assoc1.is_a?(HasManyAssocParams) && assoc2.is_a?(HasManyAssocParams))
      Relation.new("#{assoc2.other_table}.*",
        "#{assoc1.other_table}
        JOIN #{assoc2.other_table}
        ON #{assoc1.other_table}.#{assoc2.foreign_key}
            = #{assoc2.other_table}.#{assoc2.primary_key}",
            ["#{assoc1.other_table}.#{assoc1.foreign_key}
            = #{self.send(assoc1.primary_key)}"],
            assoc2.other_class)
    else
      raise "nonsensical has_many_through"
    end
  end
end

require_relative './associatable'
require_relative './db_connection' # use DBConnection.execute freely here.
require_relative './mass_object'
require_relative './relation'
require_relative './searchable'
require 'active_support/inflector'

class SQLObjectBase < MassObject

  extend Searchable

  extend Associatable

  # sets the table_name
  def self.set_table_name(table_name)
    @table_name = table_name
  end

  # gets the table_name
  def self.table_name
    return @table_name unless @table_name.nil?

    # default
    self.to_s.underscore.pluralize
  end

  # querys database for all records for this type. (result is array of hashes)
  # converts resulting array of hashes to an array of objects by calling ::new
  # for each row in the result. (might want to call #to_sym on keys)
  def self.all
    relation = Relation.new("*",table_name, [], self)
  end

  # querys database for record of this type with id passed.
  # returns either a single object or nil.
  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
      SELECT *
      FROM #{table_name}
      WHERE id = ?
    SQL

    if results.length == 0
      nil
    else
      self.new(results.first)
    end
  end

  attr_accessor :id

  # call either create or update depending if id is nil.
  def save
    if @id.nil?
      create
    else
      update
    end
  end

    # executes query that creates record in db with objects attribute values.
  # use send and map to get instance values.
  # after, update the id attribute with the helper method from db_connection
  def create
    attributes_string = self.class.attributes.join(", ")

    question_marks = (["?"] * self.class.attributes.length).join(", ")

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO #{self.class.table_name}
      (#{self.class.attributes.join(", ")})
      VALUES (#{question_marks})
    SQL

    @id = DBConnection.last_insert_row_id
  end

  def destroy
    DBConnection.execute(<<-SQL, id)
      DELETE FROM #{self.class.table_name}
      WHERE id = ?
    SQL
  end

  def attribute_values
    self.class.attributes.map do |attribute|
      send(attribute)
    end
  end
  # executes query that updates the row in the db corresponding to this instance
  # of the class. use "#{attr_name} = ?" and join with ', ' for set string.
  def update
    attributes_string = self.class.attributes.map do |attr|
      "#{attr} = ?"
    end.join(", ")

    DBConnection.execute(<<-SQL, *attribute_values)
      UPDATE #{self.class.table_name}
      SET #{attributes_string}
      WHERE id = #{@id}
    SQL
  end
end

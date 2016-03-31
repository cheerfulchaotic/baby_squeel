require 'baby_squeel/join_dependency'

module BabySqueel
  class NotFoundError < StandardError
    def initialize(model_name, name)
      super "There is no column or association named '#{name}' for #{model_name}."
    end
  end

  class AssociationNotFoundError < StandardError
    def initialize(model_name, name)
      super "Association named '#{name}' was not found for #{model_name}."
    end
  end

  class Table
    attr_accessor :_scope, :_on, :_join, :_table

    def initialize(scope)
      @_scope = scope
      @_table = scope.arel_table
      @_join = Arel::Nodes::InnerJoin
    end

    # See Arel::Table#[]
    def [](key)
      Nodes::Attribute.new(self, key)
    end

    # Constructs a new BabySqueel::Association. Raises
    # an exception if the association is not found.
    def association(name)
      if reflection = _scope.reflect_on_association(name)
        Association.new(self, reflection)
      else
        raise AssociationNotFoundError.new(_scope.model_name, name)
      end
    end

    def sift(sifter_name, *args)
      Nodes.wrap _scope.public_send("sift_#{sifter_name}", *args)
    end

    # Alias a table. This is only possible when joining
    # an association explicitly.
    def alias(alias_name)
      clone.alias! alias_name
    end

    def alias!(alias_name)
      self._table = _table.alias(alias_name)
      self
    end

    # Instruct the table to be joined with an INNER JOIN.
    def outer
      clone.outer!
    end

    def outer!
      self._join = Arel::Nodes::OuterJoin
      self
    end

    # Instruct the table to be joined with an INNER JOIN.
    def inner
      clone.inner!
    end

    def inner!
      self._join = Arel::Nodes::InnerJoin
      self
    end

    # Specify an explicit join.
    def on(node)
      clone.on! node
    end

    def on!(node)
      self._on = Arel::Nodes::On.new(node)
      self
    end

    # This method will be invoked by BabySqueel::Nodes::unwrap. When called,
    # there are two possible outcomes:
    #
    # 1. Join explicitly using an on clause.
    # 2. Resolve the assocition's join clauses using ActiveRecord.
    #
    def _arel(associations = [])
      JoinDependency.new(self, associations)
    end

    private

    def resolve(name)
      if _scope.column_names.include?(name.to_s)
        self[name]
      elsif _scope.reflect_on_association(name)
        association(name)
      end
    end

    def respond_to_missing?(name, *)
      resolve(name).present? || super
    end

    def method_missing(name, *args, &block)
      return super if !args.empty? || block_given?

      resolve(name) || begin
        raise NotFoundError.new(_scope.model_name, name)
      end
    end
  end
end

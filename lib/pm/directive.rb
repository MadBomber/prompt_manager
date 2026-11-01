# frozen_string_literal: true

# Base class for all directive categories.
#
# Subclass to define a category of directives. Use `desc` immediately
# before a method definition to mark it as a directive and provide its
# help description. Methods without a preceding `desc` are ordinary
# helpers and will not be registered.
#
# Use Ruby's own `alias_method` to create directive aliases;
# they are detected automatically via UnboundMethod#original_name.
#
# Example:
#
#   class MyDirectives < PM::Directive
#     desc "Greet someone"
#     def greet(ctx, name)
#       "Hello, #{name}!"
#     end
#     alias_method :hi, :greet
#   end
#
#   PM::Directive.register_all

module PM
  class Directive
    # Centralized list of all subclasses across the hierarchy.
    @directive_subclasses = []

    class << self
      # ---- Subclass tracking ------------------------------------------------

      def inherited(subclass)
        PM::Directive.directive_subclasses << subclass
        super
      end

      def directive_subclasses
        if equal?(PM::Directive)
          @directive_subclasses
        else
          PM::Directive.directive_subclasses
        end
      end

      # ---- Description helper -----------------------------------------------
      # Call `desc "text"` on the line immediately before `def method_name`.

      def desc(text)
        @_pending_desc = text
      end

      # ---- Automatic metadata capture via method_added ----------------------

      def method_added(method_name)
        if @_pending_desc
          directive_descriptions[method_name] = @_pending_desc
          @_pending_desc = nil
        else
          record_alias(method_name)
        end
        super
      end

      # Per-subclass metadata stores.

      def directive_descriptions
        @directive_descriptions ||= {}
      end

      def directive_aliases
        @directive_aliases ||= {}
      end

      # ---- Category name derived from class name ----------------------------
      # PM::CoreDirectives        --> "Core"
      # AIA::WebAndFileDirectives --> "Web And File"

      def category_name
        name.split('::').last
            .sub(/Directives$/, '')
            .gsub(/([a-z])([A-Z])/, '\1 \2')
      end

      # ---- Singleton instance per subclass ----------------------------------

      def instance
        @instance
      end

      # ---- Dispatch block builder -------------------------------------------
      # Override in subclasses to customize how directive methods are called.
      # The default passes (ctx, *args) straight through.

      def build_dispatch_block(inst, method_name)
        proc { |ctx, *args| inst.send(method_name, ctx, *args) }
      end

      # ---- PM registration --------------------------------------------------
      # Creates one instance per subclass and registers every described method
      # (plus its aliases). Safe to call repeatedly: a subclass may re-register
      # its own names, and a later subclass may override an earlier one. A name
      # claimed with PM.register raises DirectiveAlreadyRegisteredError.

      def register_all
        PM::Directive.directive_subclasses.each do |klass|
          next if klass.directive_descriptions.empty?

          klass.instance_variable_set(:@instance, klass.new)
          inst = klass.instance

          klass.directive_descriptions.each_key do |method_name|
            aliases = klass.directive_aliases[method_name] || []
            block   = klass.build_dispatch_block(inst, method_name)
            PM.send(:register_from_class, klass, [method_name, *aliases], block)
          end
        end
        nil
      end

      private

      # Detects aliases created by alias_method: UnboundMethod#original_name
      # differs from the method name when the method is an alias.
      def record_alias(method_name)
        um       = instance_method(method_name)
        original = um.original_name
        return if original == method_name || !directive_descriptions.key?(original)

        (directive_aliases[original] ||= []) << method_name
      rescue NameError
        # The method may reference constants that are not yet defined at load time.
      end
    end
  end
end

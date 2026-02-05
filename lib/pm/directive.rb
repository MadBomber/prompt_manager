# frozen_string_literal: true

# lib/pm/directive.rb
#
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

module PM
  class Directive
    # Centralized list of all subclasses across the hierarchy.
    # Initialized here on PM::Directive; the inherited hook always
    # appends to this specific array.
    @directive_subclasses = []

    class << self
      # ---- Subclass tracking ------------------------------------------------
      # Every subclass (direct or indirect) is tracked in PM::Directive's
      # centralized list so register_all can find them all.

      def inherited(subclass)
        PM::Directive.directive_subclasses << subclass
        super
      end

      # Returns the centralized subclass list.  Only meaningful when called
      # on PM::Directive itself; subclasses delegate here explicitly.
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
          # Detect aliases created by alias_method.
          # UnboundMethod#original_name returns the original method name;
          # when it differs from method_name, this method is an alias.
          begin
            um = instance_method(method_name)
            original = um.original_name
            if original != method_name && directive_descriptions.key?(original)
              (directive_aliases[original] ||= []) << method_name
            end
          rescue NameError
            # ignore — method may reference undefined constants at load time
          end
        end
        super
      end

      # Per-subclass metadata stores (instance variables on the class object).

      def directive_descriptions
        @directive_descriptions ||= {}
      end

      def directive_aliases
        @directive_aliases ||= {}
      end

      # ---- Category name derived from class name ----------------------------
      # PM::CoreDirectives        --> "Core"
      # AIA::WebAndFileDirectives --> "Web and File"

      def category_name
        name.split('::').last
            .sub(/Directives$/, '')
            .gsub(/([a-z])([A-Z])/, '\1 \2')
      end

      # ---- Singleton instance per subclass ----------------------------------
      # Created by register_all, accessible for tests and state management.

      def instance
        @instance
      end

      # ---- Dispatch block builder -------------------------------------------
      # Override in subclasses to customize how directive methods are called.
      # The default passes (ctx, *args) straight through — suitable for
      # PM::CoreDirectives whose methods use the RenderContext.

      def build_dispatch_block(inst, method_name)
        proc { |ctx, *args| inst.send(method_name, ctx, *args) }
      end

      # ---- PM registration --------------------------------------------------
      # Creates one instance per subclass and registers every described
      # method (plus its aliases) with PM.

      def register_all
        PM::Directive.directive_subclasses.each do |klass|
          next if klass.directive_descriptions.empty?

          klass.instance_variable_set(:@instance, klass.new)
          inst = klass.instance

          klass.directive_descriptions.each_key do |method_name|
            aliases = klass.directive_aliases[method_name] || []
            names   = [method_name, *aliases]

            # Remove previously registered names (idempotent re-init)
            names.each { |n| PM.directives.delete(n.to_sym) }

            block = klass.build_dispatch_block(inst, method_name)
            PM.register(*names, &block)
          end
        end
      end
    end
  end
end

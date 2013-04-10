class RoutedTree
  class Mapper
    def initialize(tree_class)
      @tree_class = tree_class
      @root_path = []
    end

    def config(&block)
      instance_eval(&block)
    end

    def root_path(*args)
      args.count == 0 ? @root_path : (@root_path = args)
    end

    def child_class
      @tree_class.child_class
    end

    def map(*args, &block)
      if args.last.is_a?(Hash)
        config = args.pop

        key = config.keys.first
        config[:to] ||= config.delete(key)
      elsif block_given?
        key = args.shift
        config = { to: block }
      end

      if key.is_a?(String)
        keys = [*root_path, *key.split('/').map(&:intern)]
        branch = keys.inject(routes) { |memo, key| memo[key] ||= {} }
        branch[:_] = config.each_with_object({}) do |(k, v), ret|
          # change all config keys to start with '_' to distinguish them from route keys
          ret[k.to_s.sub(/^_?/, '_').to_sym] = v
        end
      end
    end

    def routes
      @routes ||= {}
    end

    def relative_routes(*keys)
      keys.inject(routes) { |memo, key| memo && memo[key] }
    end

    def symbol_factory(config)
      ->(*args){
        # Will crash & burn unless last arg is a hash
        #   containing a :parent member
        args.last[:contents] = contents = args.last[:parent].send(config[:_to], *args)
        if contents.is_a?(Enumerable)
          config[:_class].new(*args)
        else
          contents
        end
      }
    end

    def alias_factory(config)
      dest_paths = [config[:_to]].flatten # allow array or string config

      ->(*args){
        options = args.last
        ret = nil
        ancestor = options[:parent]
        ancestor = ancestor.parent while ancestor.full_route.any?

        dest_paths.each do |dest_path|
          dest_path = dest_path.split('/').map(&:intern)

          # Trim parent root path from configured destination
          #
          # Will crash & burn unless last arg is a hash
          #   containing a :parent member
          if ancestor.contents(*dest_path)
            # construct with substitute path
            options[:contents] = ancestor.contents(*dest_path)
            ret = config[:_class].new(*args)
            break
          end
        end

        ret
      }
    end

    def factory_with(config)
      config[:_class] ||= child_class

      if config[:_to].respond_to?(:new)
        ->(*args){ config[:_to].new(*args) }
      elsif config[:_to].respond_to?(:call)
        config[:_to]
      elsif config[:_to].is_a? Symbol
        symbol_factory(config)
      elsif config[:_to].is_a?(Array) || config[:_to].is_a?(String)
        alias_factory(config)
      else
        ->(*args){ config[:_class].new(*args) }
      end
    end

    def config_for_path(*path)
      parts = path.map do |part|
        if part.is_a?(String)
          part.split('/').map(&:to_sym)
        else
          part
        end
      end
      parts.flatten!

      branch = routes
      while branch && (part = parts.shift)
        branch = branch[part]
      end

      branch && (branch[:_] || branch)
    end

    def factory_for(*path)
      c = config_for_path(*path)
      c && factory_with(c)
    end
  end
end

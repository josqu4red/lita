module Lita
  # Handlers use this class to define HTTP routes for the built-in web
  # server.
  class HTTPRoute
    # The handler registering the route.
    # @return [Lita::Handler] The handler.
    attr_reader :handler_class

    # The HTTP method for the route (GET, POST, etc.).
    # @return [String] The HTTP method.
    attr_reader :http_method

    # The name of the instance method in the handler to call for the route.
    # @return [Symbol, String] The method name.
    attr_reader :method_name

    # The URL path component specified in the handler, possibly containing dynamic parts
    # @return [String] The path.
    attr_reader :path

    # The regex created from the above URL path, that will trigger the route.
    # @return [String] The compiled_path.
    attr_reader :compiled_path

    # Flag indicating if route contains dynamic parts
    # @return [TrueClass, FalseClass] The flag
    attr_reader :dynamic
    alias_method :dynamic?, :dynamic

    # Optionnal route named params for dynamic routes
    # @return [Array] The params collection
    attr_reader :params

    # @param handler_class [Lita::Handler] The handler registering the route.
    def initialize(handler_class)
      @handler_class = handler_class
    end

    class << self
      private

      # @!macro define_http_method
      #   @method $1(path, method_name)
      #   Defines a new route with the "$1" HTTP method.
      #   @param path [String] The URL path component that will trigger the
      #     route.
      #   @param method_name [Symbol, String] The name of the instance method in
      #     the handler to call for the route.
      #   @return [void]
      def define_http_method(http_method)
        define_method(http_method) do |path, method_name|
          route(http_method.to_s.upcase, path, method_name)
        end
      end
    end

    define_http_method :get
    define_http_method :post
    define_http_method :put
    define_http_method :patch
    define_http_method :delete
    define_http_method :options
    define_http_method :link
    define_http_method :unlink

    private

    # Creates a new HTTP route.
    def route(http_method, path, method_name)
      @http_method = http_method
      @path = path
      @method_name = method_name

      compile
      handler_class.http_routes << self
    end

    # Converts route to regex, extracting params if present
    def compile
      @dynamic = false
      @params = []
      parts = path.split("/").map! do |part|
        part.gsub(/^:(\w+)$/) do |match|
          @dynamic = true
          @params << $1
          "([^/?#]+)"
        end
      end
      @compiled_path = /\A#{parts.join("/")}\z/
    end
  end
end

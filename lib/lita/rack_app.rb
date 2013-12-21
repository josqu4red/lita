module Lita
  # A +Rack+ application to serve routes registered by handlers.
  class RackApp
    # All registered paths. Used to respond to HEAD requests.
    # @return [Array<String>] The array of paths.
    attr_reader :all_paths

    # The currently running robot.
    # @return [Lita::Robot] The robot.
    attr_reader :robot

    # A hash mapping HTTP request methods and paths to handlers and methods.
    # @return [Hash] The mapping.
    attr_reader :routes

    # @param robot [Lita::Robot] The currently running robot.
    def initialize(robot)
      @robot = robot
      @routes = Hash.new { |h, k| h[k] = {} }
      compile
    end

    def call(env)
      request = Rack::Request.new(env)
      mapping = get_mapping(request)

      if mapping
        process_request(mapping, request)
      elsif request.head? && !all_paths.select{ |path, route| request.path =~ path }.empty?
        Lita.logger.info "HTTP HEAD #{request.path} was a 204."
        [204, {}, []]
      else
        Lita.logger.info <<-LOG.chomp
HTTP #{request.request_method} #{request.path} was a 404.
LOG
        [404, {}, ["Route not found."]]
      end
    end

    # Creates a +Rack+ application from the compiled routes.
    # @return [Rack::Builder] The +Rack+ application.
    def to_app
      app = Rack::Builder.new
      app.run(self)
      app
    end

    private

    # Collect all registered paths. Used for responding to HEAD requests.
    def collect_paths
      @all_paths = routes.values.map { |hash| hash.keys }.flatten
    end

    # Registers routes in the route mapping for each handler's defined routes.
    def compile
      Lita.handlers.each do |handler|
        handler.http_routes.each { |route| register_route(handler, route) }
      end
      collect_paths
    end

    def get_mapping(request)
      routes[request.request_method].select{ |path, route| request.path =~ path }.values.first
    end

    # Registers a route.
    def register_route(handler, route)
      if @routes[route.http_method][route.compiled_path]
        Lita.logger.fatal <<-ERR.chomp
#{handler.name} attempted to register an HTTP route that was already \
registered: #{route.http_method} "#{route.path}" (#{route.compiled_path})
ERR
        abort
      end

      Lita.logger.debug <<-LOG.chomp
Registering HTTP route: #{route.http_method} #{route.path} (#{route.compiled_path}) to \
#{handler}##{route.method_name}.
LOG
      @routes[route.http_method][route.compiled_path] = route
    end

    #
    def process_request(mapping, request)
      if mapping.dynamic?
        match = mapping.compiled_path.match request.path
        path_params = Hash[mapping.params.zip(match.captures)]
        request.params.merge!(path_params)
      end

      serve(mapping, request)
    end

    def serve(mapping, request)
      Lita.logger.info <<-LOG.chomp
Routing HTTP #{request.request_method} #{request.path} to \
#{mapping.handler_class}##{mapping.method_name}.
LOG
      response = Rack::Response.new
      instance = mapping.handler_class.new(robot)
      instance.public_send(mapping.method_name, request, response)
      response.finish
    end
  end
end

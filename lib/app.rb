require 'posix/spawn'
require 'sinatra/base'

class FaceCrime
  class App < Sinatra::Base
    enable  :raise_errors, :logging
    disable :show_exceptions

    helpers do
      def output_path
        @overlay_path ||= File.expand_path("../tmp/", File.dirname(__FILE__))
      end

      def output_filename(url, template)
        Digest::SHA1.hexdigest(url + template) + ".png"
      end

      def overlay_executable
        @overlay_executable ||= File.expand_path("../script/overlay", File.dirname(__FILE__))
      end
    end

    error do
    end

    get '/overlay' do
      template   = params['template'] || "rohan"
      input_file = params['url']
      output_file = output_filename(input_file, template)
      full_output_file = File.join(output_path, output_file)

      args = [
        overlay_executable,
        '-i', input_file,
        '-o', full_output_file
      ]
      environ = {
        'RUBYOPT' => ''
      }

      unless File.exist?(full_output_file)
        child  = POSIX::Spawn::Child.new(environ, *args)
        if child.status.success?
          status 200
        else
          status 500
        end
      end
      send_file(full_output_file, {:filename => output_file, :stream => true, :type => 'image/png', :disposition => 'inline'})
    end

    get '/status' do
      status 200
      "OK"
    end
  end
end

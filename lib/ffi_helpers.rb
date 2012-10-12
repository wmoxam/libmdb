module FFIHelpers
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    private
    def soft_attach(method, *args)
      begin
        attach_function method, *args
      rescue Exception => e
         STDERR.puts "Warning, could not attach #{method} because #{e.message}"
         return false
      end
      true
    end
  end
end

namespace :images do
  desc "Optimize a generated image. Usage: rake images:optimize[path,format,quality]"
  task :optimize, [ :path, :format, :quality ] => :environment do |_, args|
    path = args[:path] || ENV["PATH"]
    unless path
      warn "Usage: rake images:optimize[path,format,quality]"
      exit 1
    end
    fmt = args[:format] || ENV["FORMAT"]
    q = (args[:quality] || ENV["QUALITY"] || 85).to_i
    result = Images::OptimizeService.call(path: path, output_path: path, format: fmt, quality: q)
    if result.success?
      puts "Optimized: #{result.value[:output_path]} (#{result.value[:format]} q=#{result.value[:quality]})"
    else
      warn "Optimization failed: #{result.error.message}"
      exit 1
    end
  end
end

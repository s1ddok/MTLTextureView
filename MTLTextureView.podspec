Pod::Spec.new do |s|

  s.name         = "MTLTextureView"
  s.version      = "0.1.1"
  s.summary      = "Tiny UIView subclass that acts like UIImageView but for MTLTextures"

  s.description  = <<-DESC
  This control can be useful when you need to display contents of MTLTexture in your application. Majorly for debugging purposes.
                   DESC

  s.homepage     = "https://github.com/s1ddok/MTLTextureView"

  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author           = { "Andrey Volodin" => "siddok@gmail.com" }
  s.social_media_url = "http://twitter.com/s1ddok"

  #  When using multiple platforms
  s.ios.deployment_target = "11.0"
  s.source        = { :git => "https://github.com/s1ddok/MTLTextureView.git", :tag => "#{s.version}" }
  s.source_files  = "MTLTextureView"
  s.swift_version = "4.2"
  s.frameworks = "Metal", "QuartzCore"
end

require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-apple-game-controller"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.license      = package["license"]
  s.authors      = { "author" => "jim@blueskylabs.com" }
  s.homepage     = "https://github.com/example/react-native-apple-game-controller"
  s.source       = { :git => "https://github.com/example/react-native-apple-game-controller.git", :tag => s.version }

  s.osx.deployment_target = "14.0"
  s.source_files = "macos/**/*.{h,mm}"
  s.osx.frameworks = "GameController"

  install_modules_dependencies(s)
end

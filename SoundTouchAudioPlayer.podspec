Pod::Spec.new do |s|
	s.name = "SoundTouchAudioPlayer"
	s.version = "1.0"
	s.summary = "AudioPlayer that uses SoundTouch"
	s.homepage = "http://github.com"
	s.license = ":type => 'MIT'"
	s.authors = { "Mike Coleman" => "a@b.com", "Stephan Heilner" => "a@b.com" }
	s.source = { :git => "https://github.com/stephanheilner/SoundTouchAudioPlayer.git", :branch => 'cocoapods' }
	s.source_files = '*.{h,m,mm}'
	s.requires_arc = false 
	s.platform = :ios, '6.0'
	s.frameworks = 'MediaPlayer', 'CoreMedia', 'AudioToolbox'
end

Pod::Spec.new do |s|

    s.name = 'LightBundleSDK'
    s.platform = :ios, "7.0"
    s.version = '1.0'
    s.license = 'MIT'
    s.summary = 'LightBundleSDK for cxb.'
    s.homepage = 'https://github.com/loverbabyz/LightBundle_SDK_iOS'
    s.author = { 'renwenchao' => 'renwenchao@chexiang.com' }
    s.source = { :git => 'https://github.com/loverbabyz/LightBundle_SDK_iOS.git',
                 :tag => "#{s.version}"
               }


    s.source_files = "LightBundle/LightBundle/*.{h,m}"

    s.subspec 'BasePlugin' do |ss|
    ss.source_files = 'LightBundle/LightBundle/BasePlugin/*.{h,m}'
    ss.public_header_files = 'LightBundle/LightBundle/BasePlugin/*.h'
    end

    s.subspec 'model' do |ss|
    ss.source_files = 'LightBundle/LightBundle/model/*.{h,m}'
    ss.public_header_files = 'LightBundle/LightBundle/model/*.h'
    end

    s.subspec 'ServicePlugin' do |ss|
    ss.source_files = 'LightBundle/LightBundle/ServicePlugin/*.{h,m}'
    ss.public_header_files = 'LightBundle/LightBundle/ServicePlugin/*.h'
    end

    s.subspec 'private' do |ss|
    ss.source_files = 'LightBundle/LightBundle/private/*.{h,m}'
    ss.public_header_files = 'LightBundle/LightBundle/private/*.h'

        ss.subspec 'LBAes' do |sss|
        sss.source_files = 'LightBundle/LightBundle/private/LBAes/*.{h,m}'
        sss.public_header_files = 'LightBundle/LightBundle/private/LBAes/*.h'
        end

        ss.subspec 'LBAlertView' do |sss|
        sss.source_files = 'LightBundle/LightBundle/private/LBAlertView/*.{h,m}'
        sss.public_header_files = 'LightBundle/LightBundle/private/LBAlertView/*.h'
        end

        ss.subspec 'LBToast' do |sss|
        sss.source_files = 'LightBundle/LightBundle/private/LBToast/*.{h,m}'
        sss.public_header_files = 'LightBundle/LightBundle/private/LBToast/*.h'
        end

        ss.subspec 'LBZXingObjC' do |sss|
        sss.source_files = 'LightBundle/LightBundle/private/LBZXingObjC/**/*.{h,m}'
        sss.public_header_files = 'LightBundle/LightBundle/private/LBZXingObjC/**/*.h'
        end

        ss.subspec 'LBCustomPicker' do |sss|
        sss.source_files = 'LightBundle/LightBundle/private/LBCustomPicker/*.{h,m}'
        sss.public_header_files = 'LightBundle/LightBundle/private/LBCustomPicker/*.h'
        end

        ss.subspec 'LBNSDataBase64' do |sss|
        sss.source_files = 'LightBundle/LightBundle/private/LBNSDataBase64/*.{h,m}'
        sss.public_header_files = 'LightBundle/LightBundle/private/LBNSDataBase64/*.h'
        end

        ss.subspec 'LBLocationManager' do |sss|
        sss.source_files = 'LightBundle/LightBundle/private/LBLocationManager/*.{h,m}'
        sss.public_header_files = 'LightBundle/LightBundle/private/LBLocationManager/*.h'
        end

        ss.subspec 'LBNJKWebViewProgress' do |sss|
        sss.source_files = 'LightBundle/LightBundle/private/LBNJKWebViewProgress/*.{h,m}'
        sss.public_header_files = 'LightBundle/LightBundle/private/LBNJKWebViewProgress/*.h'
        end

        ss.subspec 'LBQRCodeReaderViewController' do |sss|
        sss.source_files = 'LightBundle/LightBundle/private/LBQRCodeReaderViewController/*.{h,m}'
        sss.public_header_files = 'LightBundle/LightBundle/private/LBQRCodeReaderViewController/*.h'
        end
    end

#    s.vendored_libraries = "output/libLightBundle.a"
    s.requires_arc = true
    s.frameworks = 'AVFoundation', 'MessageUI', 'Foundation', 'CoreLocation', 'UIKit', 'WebKit'
end
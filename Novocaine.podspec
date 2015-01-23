Pod::Spec.new do |spec|
    spec.name         = 'Novocaine'
    spec.version      = '0.0.1'
    spec.summary      = 'Novocaine'
    spec.source_files = 'Novocaine/'
    spec.requires_arc = true
    spec.ios.deployment_target = '5.1'
    spec.author       = {"Alex Wiltschko" => "alex.bw@gmail.com" }
    spec.frameworks   = 'AudioToolbox','Accelerate'
    spec.libraries    = 'stdc++'
end

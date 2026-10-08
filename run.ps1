$env:PATH = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User') + ';' + $env:PATH
flutter run -d chrome

@echo off
rustup target add i686-pc-windows-msvc
:: 32-bit build
cargo build --release --target=i686-pc-windows-msvc
:: Compression disabled as it gave some false positives on virustotal
:: May re-enable in the future if we ever get a signing certificate

:: tools\upx.exe target\release\*.exe

:: Renames the executable to SyntaxPlayerLauncher.exe from syntax_bootstrapper.exe
ren target\i686-pc-windows-msvc\release\syntax_bootstrapper.exe SyntaxPlayerLauncher.exe
use chrono::format;
use colored::*;
use std::path::PathBuf;
use reqwest::Client;
use dirs::data_local_dir;
use futures_util::StreamExt;
use md5;
use zip_extract;
use sha1::{Sha1, Digest};

#[cfg(target_os = "windows")]
use std::os::windows::prelude::FileExt;
#[cfg(target_os = "windows")]
use winreg::enums::*;
#[cfg(target_os = "windows")]
use winreg::RegKey;
#[cfg(not(target_os = "windows"))]
use std::io::prelude::*;
#[cfg(not(target_os = "windows"))]
use std::os::unix::fs::FileExt;

fn info( message : &str ) {
    let time = chrono::Local::now().format("%H:%M:%S").to_string();
    println!("[{}] [{}] {}", time.bold().blue(), "INFO".bold().green(), message);
}

fn error( message : &str ) {
    let time = chrono::Local::now().format("%H:%M:%S").to_string();
    println!("[{}] [{}] {}", time.bold().blue(), "ERROR".bold().red(), message);
}

#[cfg(debug_assertions)]
fn debug( message : &str ) {
    let time = chrono::Local::now().format("%H:%M:%S").to_string();
    println!("[{}] [{}] {}", time.bold().blue(), "DEBUG".bold().yellow(), message);
}

#[cfg(not(debug_assertions))]
fn debug( message : &str ) {}

pub async fn http_get( client: &Client ,url: &str ) -> Result<String, reqwest::Error> {
    debug(&format!("{} {}", "GET".green(), url.bright_blue()));
    let response = client.get(url).send().await;
    if (response.is_err()) {
        debug(&format!("Failed to fetch {}", url.bright_blue()));
        return Err(response.err().unwrap());
    }
    let response_body = response.unwrap().text().await.unwrap();
    Ok(response_body)
}

pub async fn download_file( client: &Client, url: &str, path: &PathBuf ) {
    debug(&format!("{} {}", "GET".green(), url.bright_blue()));
    let response = client.get(url).send().await.unwrap();
    let content_length = response.content_length().unwrap();
    debug(&format!("Content Length: {}", content_length));

    let time = chrono::Local::now().format("%H:%M:%S").to_string();
    let pg_bar_str = "                {spinner:.green} [{bar:40.cyan/blue}] {bytes}/{total_bytes} ({eta})";
    let progress_bar = indicatif::ProgressBar::new(content_length);
    let progress_style = indicatif::ProgressStyle::default_bar()
        .template(
            format!("{}\n{}", 
            format!(
                "[{}] [{}] {}", 
                time.bold().blue(), 
                "INFO".bold().green(), 
                &format!("Downloading {}", &url.bright_blue())
            ),
            pg_bar_str).as_str()
        )
        .unwrap().progress_chars("#>-");
    progress_bar.set_style(progress_style);
    progress_bar.set_message("Downloading File");

    let file = std::fs::File::create(path).unwrap();
    let mut downloaded: u64 = 0;
    let mut stream = response.bytes_stream();

    while let Some(item) = stream.next().await {
        let chunk = item.or(Err(format!("Error while downloading file"))).unwrap();
        #[cfg(target_os = "windows")]
        {
            file.seek_write(chunk.as_ref(), downloaded).unwrap();
        }
        #[cfg(not(target_os = "windows"))]
        {
            file.write_at(chunk.as_ref(), downloaded).unwrap();
        }
        let new = std::cmp::min(downloaded + (chunk.len() as u64), content_length);
        downloaded = new;
        progress_bar.set_position(new);
    }
    progress_bar.finish();
    info(format!("Finished downloading {}", url.green()).as_str());
}

pub async fn download_file_prefix( client: &Client, url: &str, path_prefix : &PathBuf ) -> PathBuf {
    let path = path_prefix.join(generate_md5(url).await);
    download_file(client, url, &path).await;
    return path;
}

pub async fn generate_md5( input : &str ) -> String {
    let hashed_input = md5::compute(input.as_bytes());
    return format!("{:x}", hashed_input);
}

pub async fn create_folder_if_not_exists( path: &PathBuf ) {
    if !path.exists() {
        info(&format!("Creating folder {}", path.to_str().unwrap().bright_blue()));
        std::fs::create_dir_all(path).unwrap();
    }
}

pub async fn get_sha1_hash_of_file( path: &PathBuf ) -> String {
    let mut file = std::fs::File::open(path).unwrap();
    let mut hasher = Sha1::new();
    std::io::copy(&mut file, &mut hasher).unwrap();
    let hash = hasher.finalize();
    return format!("{:x}", hash);
}

fn get_installation_directory() -> PathBuf {
    return PathBuf::from(data_local_dir().unwrap().to_str().unwrap()).join("Syntax");
}

#[tokio::main]
async fn main() {

    // Clear the terminal before printing the startup text
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("cmd")
        .args(&["/c", "cls"])
        .spawn()
        .expect("cls command failed to start")
        .wait()
        .expect("failed to wait");
    }
    #[cfg(not(target_os = "windows"))]
    {
        std::process::Command::new("clear").spawn().unwrap();
    }

    let args: Vec<String> = std::env::args().collect();
    let base_url : &str = "www.syntax.eco";
    let mut setup_url : &str = "setup.syntax.eco";
    let fallback_setup_url : &str = "d2f3pa9j0u8v6f.cloudfront.net";
    let mut bootstrapper_filename :&str = "SyntaxPlayerLauncher.exe";
    #[cfg(not(target_os = "windows"))]
    {
        bootstrapper_filename = "SyntaxPlayerLinuxLauncher";
    }
    let build_date = include_str!(concat!(env!("OUT_DIR"), "/build_date.txt"));
    let startup_text = format!("
    .d8888b. Y88b   d88P  888b    888 88888888888     d8888 Y88b   d88P 
    d88P  Y88b Y88b d88P  8888b   888     888        d88888  Y88b d88P  
    Y88b.       Y88o88P   88888b  888     888       d88P888   Y88o88P   
     \"Y888b.     Y888P    888Y88b 888     888      d88P 888    Y888P    
        \"Y88b.    888     888 Y88b888     888     d88P  888    d888b    
          \"888    888     888  Y88888     888    d88P   888   d88888b   
    Y88b  d88P    888     888   Y8888     888   d8888888888  d88P Y88b  
    \"Y8888P\"     888     888    Y888     888  d88P     888 d88P   Y88b
     
   {} | Build Date: {} | Version: {}", base_url ,build_date, env!("CARGO_PKG_VERSION"));

    // Format the startup text to be centered
    let mut terminal_width = 80;
    if let Some((w, _h)) = term_size::dimensions() {
        terminal_width = w;
    }
    if terminal_width < 80 {
        print!("{}\n", format!("SYNTAX Bootstrapper | {} | Build Date: {} | Version: {}", base_url, build_date, env!("CARGO_PKG_VERSION")).to_string().magenta().cyan().italic().on_black()); // Fallback message
    } else {
        let startup_text_lines = startup_text.lines().collect::<Vec<&str>>();
        //println!("{}", startup_text.bold().blue().on_black());
    
        // print all lines except the last one
        for line in &startup_text_lines[0..startup_text_lines.len() - 1] {
            let spaces = (terminal_width - line.len()) / 2;
            let formatted_line = format!("{}{}", " ".repeat(spaces), line);
            println!("{}", formatted_line.bright_magenta().italic().on_black());
        }

        // print last line as a different color
        let last_line = startup_text_lines[startup_text_lines.len() - 1];
        let spaces = (terminal_width - last_line.len()) / 2;
        let last_line = format!("{}{}", " ".repeat(spaces), last_line);
        println!("{}\n", last_line.magenta().cyan().italic().on_black());
    }

    let http_client: Client = reqwest::Client::builder()
        .no_gzip()
        .build()
        .unwrap();
    debug(format!("Setup Server: {} | Base Server: {}", setup_url.bright_blue(), base_url.bright_blue()).as_str());
    debug("Fetching latest client version from setup server");
    
    let latest_client_version : String;
    let latest_client_version_response = http_get(&http_client ,&format!("https://{}/version", setup_url)).await;
    match latest_client_version_response {
        Ok(latest_client_version_result) => {
            debug(&format!("Latest Client Version: {}", latest_client_version_result.bright_blue()));
            latest_client_version = latest_client_version_result;
        },
        Err(e) => {
            error(&format!("Failed to fetch latest client version from setup server: [{}], attempting to fallback to {}", e.to_string().bright_red(), fallback_setup_url.bright_blue()));
            let fallback_client_version_response = http_get(&http_client ,&format!("https://{}/version", fallback_setup_url)).await;
            match fallback_client_version_response {
                Ok(fallback_client_version_result) => {
                    info(&format!("Successfully fetched latest client version from fallback setup server: {}", fallback_setup_url.bright_blue()));
                    debug(&format!("Latest Client Version: {}", fallback_client_version_result.bright_blue()));
                    latest_client_version = fallback_client_version_result;
                    setup_url = fallback_setup_url;
                },
                Err(e) => {
                    error(&format!("Failed to fetch latest client version from fallback setup server: {}, are you connected to the internet?", e));
                    std::thread::sleep(std::time::Duration::from_secs(10));
                    std::process::exit(0);
                }
            }
        }
    }

    // Wait for the latest client version to be fetched
    info(&format!("Latest Client Version: {}", latest_client_version.cyan().underline()));
    debug(&format!("Setup Server: {}", setup_url.cyan().underline()));

    let installation_directory = get_installation_directory();
    debug(&format!("Installation Directory: {}", installation_directory.to_str().unwrap().bright_blue()));
    create_folder_if_not_exists(&installation_directory).await;

    let versions_directory = installation_directory.join("Versions");
    debug(&format!("Versions Directory: {}", versions_directory.to_str().unwrap().bright_blue()));
    create_folder_if_not_exists(&versions_directory).await;

    let temp_downloads_directory = installation_directory.join("Downloads");
    debug(&format!("Temp Downloads Directory: {}", temp_downloads_directory.to_str().unwrap().bright_blue()));
    create_folder_if_not_exists(&temp_downloads_directory).await;

    let current_version_directory = versions_directory.join(format!("{}", latest_client_version));
    debug(&format!("Current Version Directory: {}", current_version_directory.to_str().unwrap().bright_blue()));
    create_folder_if_not_exists(&current_version_directory).await;

    let latest_bootstrapper_path = current_version_directory.join(bootstrapper_filename);
    // Is the program currently running from the latest version directory?
    let current_exe_path = std::env::current_exe().unwrap();
    // If the current exe path is not in the current version directory, then we need to run the latest bootstrapper ( download if needed )
    if !current_exe_path.starts_with(&current_version_directory) {
        // Check if the latest bootstrapper is downloaded
        if !latest_bootstrapper_path.exists() {
            info("Downloading the latest bootstrapper");
            // Download the latest bootstrapper
            download_file(&http_client, &format!("https://{}/{}-{}", setup_url, latest_client_version, bootstrapper_filename), &latest_bootstrapper_path).await;
        }

        // Lets compare the SHA1 hash of the latest bootstrapper to the one we are currently running
        // If they are the same, then we can continue with the update process
        // We do this because antivirus software does not like this type of behavior

        let latest_bootstrapper_hash = get_sha1_hash_of_file(&latest_bootstrapper_path).await;
        let current_exe_hash = get_sha1_hash_of_file(&current_exe_path).await;

        debug(&format!("Latest Bootstrapper Hash: {}", latest_bootstrapper_hash.bright_blue()));
        debug(&format!("Current Bootstrapper Hash: {}", current_exe_hash.bright_blue()));

        if latest_bootstrapper_hash != current_exe_hash {
            info("Starting latest bootstrapper");
            // Run the latest bootstrapper ( with the same arguments passed to us ) and exit
            #[cfg(target_os = "windows")]
            {
                let mut command = std::process::Command::new(latest_bootstrapper_path.clone());
                command.args(&args[1..]);
                match command.spawn() {
                    Ok(_) => {},
                    Err(e) => {
                        debug(&format!("Bootstrapper errored with error {}", e));
                        info("Found bootstrapper was corrupted! Downloading...");
                        std::fs::remove_file(latest_bootstrapper_path.clone()).unwrap();
                        download_file(&http_client, &format!("https://{}/{}-{}", setup_url, latest_client_version, bootstrapper_filename), &latest_bootstrapper_path).await;
                        command.spawn().expect("Bootstrapper is still corrupted.");
                        std::thread::sleep(std::time::Duration::from_secs(20));
                    }
                }
            }
            #[cfg(not(target_os = "windows"))]
            {
                // Make sure the latest bootstrapper is executable
                std::process::Command::new("chmod").arg("+x").arg(latest_bootstrapper_path.to_str().unwrap()).spawn().unwrap();

                let desktop_file_content = &format!("[Desktop Entry]
Name=Syntax Launcher
Exec={} %u
Icon={}
Type=Application
Terminal=true
Version={}
MimeType=x-scheme-handler/syntax-player;", latest_bootstrapper_path.to_str().unwrap(), latest_bootstrapper_path.to_str().unwrap(), env!("CARGO_PKG_VERSION"));
                
                let desktop_file_path = dirs::data_local_dir().unwrap().join("applications").join("syntax-player.desktop");
                std::fs::write(desktop_file_path, desktop_file_content).unwrap();

                info("Please launch SYNTAX from the website, to continue with the update process.");
                std::thread::sleep(std::time::Duration::from_secs(20));
            }
            std::process::exit(0);

        }
    }

    // Looks like we are running from the latest version directory, so we can continue with the update process
    // Check for "AppSettings.xml" in the current version directory 
    // If it doesent exist, then we got either a fresh directory or a corrupted installation
    // So delete the every file in the current version directory except for the Bootstrapper itself
    let app_settings_path = current_version_directory.join("AppSettings.xml");
    if !app_settings_path.exists() { //|| !client_executable_path.exists() {
        info("Downloading the latest client files, this may take a while.");
        for entry in std::fs::read_dir(&current_version_directory).unwrap() {
            let entry = entry.unwrap();
            let path = entry.path();
            if path.is_file() {
                if path != latest_bootstrapper_path {
                    std::fs::remove_file(path).unwrap();
                }
            } else {
                std::fs::remove_dir_all(path).unwrap();
            }
        }

        let VersionURLPrefix = format!("https://{}/{}-", setup_url, latest_client_version);

        let Client2018Zip : PathBuf = download_file_prefix(&http_client, format!("{}2018client.zip", VersionURLPrefix).as_str(), &temp_downloads_directory).await;
        let Client2020Zip : PathBuf = download_file_prefix(&http_client, format!("{}2020client.zip", VersionURLPrefix).as_str(), &temp_downloads_directory).await;
        let Client2014Zip : PathBuf = download_file_prefix(&http_client, format!("{}2014client.zip", VersionURLPrefix).as_str(), &temp_downloads_directory).await;
        let Client2016Zip : PathBuf = download_file_prefix(&http_client, format!("{}2016client.zip", VersionURLPrefix).as_str(), &temp_downloads_directory).await;
        let Client2021Zip : PathBuf = download_file_prefix(&http_client, format!("{}2021client.zip", VersionURLPrefix).as_str(), &temp_downloads_directory).await;
        info("Download finished, extracting files.");

        fn extract_to_dir( zip_file : &PathBuf, target_dir : &PathBuf ) {
            info(format!("Extracting {} to {}", zip_file.to_str().unwrap().bright_blue(), target_dir.to_str().unwrap().bright_blue()).as_str());
            let zip_file_cursor = std::fs::File::open(zip_file).unwrap();
            zip_extract::extract(zip_file_cursor, target_dir, false).unwrap();
        }

        let client_2018_directory = current_version_directory.join("Client2018");
        create_folder_if_not_exists(&client_2018_directory).await;
        extract_to_dir(&Client2018Zip, &client_2018_directory);

        let client_2020_directory = current_version_directory.join("Client2020");
        create_folder_if_not_exists(&client_2020_directory).await;
        extract_to_dir(&Client2020Zip, &client_2020_directory);

        let client_2014_directory = current_version_directory.join("Client2014");
        create_folder_if_not_exists(&client_2014_directory).await;
        extract_to_dir(&Client2014Zip, &client_2014_directory);

        let client_2016_directory = current_version_directory.join("Client2016");
        create_folder_if_not_exists(&client_2016_directory).await;
        extract_to_dir(&Client2016Zip, &client_2016_directory);

        let client_2021_directory = current_version_directory.join("Client2021");
        create_folder_if_not_exists(&client_2021_directory).await;
        extract_to_dir(&Client2021Zip, &client_2021_directory);

        info("Finished extracting files, cleaning up.");
        std::fs::remove_dir_all(&temp_downloads_directory).unwrap();

        // Install the syntax-player scheme in the registry
        info("Installing syntax-player scheme");
        #[cfg(target_os = "windows")]
        {
            let hkey_current_user = RegKey::predef(HKEY_CURRENT_USER);
            let hkey_classes_root : RegKey = hkey_current_user.open_subkey("Software\\Classes").unwrap();
            let hkey_syntax_player = hkey_classes_root.create_subkey("syntax-player").unwrap().0;
            let hkey_syntax_player_shell = hkey_syntax_player.create_subkey("shell").unwrap().0;
            let hkey_syntax_player_shell_open = hkey_syntax_player_shell.create_subkey("open").unwrap().0;
            let hkey_syntax_player_shell_open_command = hkey_syntax_player_shell_open.create_subkey("command").unwrap().0;
            let defaulticon = hkey_syntax_player.create_subkey("DefaultIcon").unwrap().0;
            hkey_syntax_player_shell_open_command.set_value("", &format!("\"{}\" \"%1\"", latest_bootstrapper_path.to_str().unwrap())).unwrap();
            defaulticon.set_value("", &format!("\"{}\",0", latest_bootstrapper_path.to_str().unwrap())).unwrap();
            hkey_syntax_player.set_value("", &format!("URL: Syntax Protocol")).unwrap();
            hkey_syntax_player.set_value("URL Protocol", &"").unwrap();
        }
        #[cfg(not(target_os = "windows"))]
        {
            // Linux support
            let desktop_file_content = &format!("[Desktop Entry]
Name=Syntax Launcher
Exec={} %u
Icon={}
Type=Application
Terminal=true
Version={}
MimeType=x-scheme-handler/syntax-player;", latest_bootstrapper_path.to_str().unwrap(), latest_bootstrapper_path.to_str().unwrap(), env!("CARGO_PKG_VERSION"));
            
            let desktop_file_path = dirs::data_local_dir().unwrap().join("applications").join("syntax-player.desktop");
            std::fs::write(desktop_file_path, desktop_file_content).unwrap();
        }

        // Write the AppSettings.xml file
        let app_settings_xml = format!(
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<Settings>
	<ContentFolder>content</ContentFolder>
	<BaseUrl>http://{}</BaseUrl>
</Settings>", base_url
        );
        std::fs::write(app_settings_path, app_settings_xml).unwrap();

        // Check for any other version directories and deletes them
        for entry in std::fs::read_dir(&versions_directory).unwrap() {
            let entry = entry.unwrap();
            let path = entry.path();
            if path.is_dir() {
                if path != current_version_directory {
                    std::fs::remove_dir_all(path).unwrap();
                }
            }
        }
    }

    // Parse the arguments passed to the bootstrapper
    // Looks something like "syntax-player://1+launchmode:play+gameinfo:TICKET+placelauncherurl:https://www.syntax.eco/Game/placelauncher.ashx?placeId=660&t=TICKET+k:l"
    debug(&format!("Arguments Passed: {}", args.join(" ").bright_blue()));
    if args.len() == 1 {
        // Just open the website
        #[cfg(target_os = "windows")]
        {
            std::process::Command::new("cmd").arg("/c").arg("start").arg("https://www.syntax.eco/games").spawn().unwrap();
            std::process::exit(0);
        }
        #[cfg(not(target_os = "windows"))]
        {
            std::process::Command::new("xdg-open").arg("https://www.syntax.eco/games").spawn().unwrap();
            std::process::exit(0);
        }
    }

    let main_args = &args[1];
    let main_args = main_args.replace("syntax-player://", "");
    let main_args = main_args.split("+").collect::<Vec<&str>>();

    let mut launch_mode = String::new();
    let mut authentication_ticket = String::new();
    let mut join_script = String::new();
    let mut client_year = String::new();
    
    for arg in main_args {
        let mut arg_split = arg.split(":");
        let key = arg_split.next().unwrap();
        let value =
            if arg_split.clone().count() > 0 {
                arg_split.collect::<Vec<&str>>().join(":")
            } else {
                String::new()
            };
        debug(&format!("{}: {}", key.bright_blue(), value.bright_blue()));
        match key {
            "launchmode" => {
                launch_mode = value.to_string();
            },
            "gameinfo" => {
                authentication_ticket = value.to_string();
            },
            "placelauncherurl" => {
                join_script = value.to_string();
            },
            "clientyear" => {
                client_year = value.to_string();
            },
            _ => {}
        }
    }

    let custom_wine = "wine";
    #[cfg(not(target_os = "windows"))]
    {
        // We allow user to specify the wine binary path in installation_directory/winepath.txt
        let wine_path_file = installation_directory.join("winepath.txt");
        if wine_path_file.exists() {
            let custom_wine = std::fs::read_to_string(wine_path_file).unwrap();
            info(&format!("Using custom wine binary: {}", custom_wine.bright_blue()));
        } else {
            info("No custom wine binary specified, using default wine command");
            info(format!("If you want to use a custom wine binary, please create a file at {} with the path to the wine binary", wine_path_file.to_str().unwrap()).as_str());
        }
    }
    let client_executable_path : PathBuf;
    debug(&client_year.to_string());
    if client_year == "2018" {
        client_executable_path = current_version_directory.join("Client2018").join("SyntaxPlayerBeta.exe");
    } else if client_year == "2020" {
        client_executable_path = current_version_directory.join("Client2020").join("SyntaxPlayerBeta.exe");
    } else if client_year == "2014" {
        client_executable_path = current_version_directory.join("Client2014").join("SyntaxPlayerBeta.exe");
    } else if client_year == "2021" {
        client_executable_path = current_version_directory.join("Client2021").join("SyntaxPlayerBeta.exe");
    } else {
        client_executable_path = current_version_directory.join("Client2016").join("SyntaxPlayerBeta.exe");
    }
    if !client_executable_path.exists() {
        // Delete AppSettings.xml so the bootstrapper will download the client again
        let app_settings_path = current_version_directory.join("AppSettings.xml");
        std::fs::remove_file(app_settings_path).unwrap();

        error("Failed to run SyntaxPlayerBeta.exe, is your antivirus removing it? The bootstrapper will attempt to redownload the client on next launch.");
        std::thread::sleep(std::time::Duration::from_secs(20));
        std::process::exit(0);
    }
    match launch_mode.as_str() {
        "play" => {
            info("Launching SYNTAX");
            #[cfg(target_os = "windows")]
            {           
                let mut command = std::process::Command::new(client_executable_path);
                command.args(&["--play","--authenticationUrl", format!("https://{}/Login/Negotiate.ashx", base_url).as_str(), "--authenticationTicket", authentication_ticket.as_str(), "--joinScriptUrl", format!("{}",join_script.as_str()).as_str()]);
                command.spawn().unwrap();
                std::thread::sleep(std::time::Duration::from_secs(5));
                std::process::exit(0);
            }
            #[cfg(not(target_os = "windows"))]
            {
                // We have to launch the game through wine
                let mut command = std::process::Command::new(custom_wine);
                command.args(&[client_executable_path.to_str().unwrap(), "--play","--authenticationUrl", format!("https://{}/Login/Negotiate.ashx", base_url).as_str(), "--authenticationTicket", authentication_ticket.as_str(), "--joinScriptUrl", format!("{}",join_script.as_str()).as_str()]);
                // We must wait for the game to exit before exiting the bootstrapper
                let mut child = command.spawn().unwrap();
                child.wait().unwrap();
                std::thread::sleep(std::time::Duration::from_secs(1));
                std::process::exit(0);
            }
        },
        _ => {
            error("Unknown launch mode, exiting.");
            std::thread::sleep(std::time::Duration::from_secs(10));
            std::process::exit(0);
        }
    }
}
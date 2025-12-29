import SwiftUI

struct ContentView: View {
    @State private var projectPath: String = ""
    @State private var logOutput: String = "Select an Android project to begin..."
    @State private var isWatchingLogs = false
    @State private var logProcess: Process?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Project Selection
            HStack {
                TextField("Android Project Path", text: $projectPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(true)
                
                Button(action: selectProject) {
                    Text("Browse...")
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Command Buttons
            VStack(spacing: 8) {
                ActionButton(title: "Build APK", action: buildAPK)
                ActionButton(title: "Install APK", action: installAPK)
                ActionButton(title: "Run on Device", action: runOnDevice)
                ActionButton(title: isWatchingLogs ? "Stop Logs" : "Show Logcat", action: toggleLogs)
            }
            .padding(.horizontal)
            
            Divider()
            
            // Log Output
            ScrollView {
                ScrollViewReader { proxy in
                    Text(logOutput)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .onChange(of: logOutput) { _ in
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                }
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .frame(maxHeight: .infinity)
            
            Text("Android Status Bar App")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
        }
        .padding(.vertical, 12)
        .frame(width: 400, height: 600)
    }
    
    private func selectProject() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                projectPath = url.path
                logOutput = "Selected project: \(url.lastPathComponent)\n"
                logOutput += "Looking for build.gradle...\n"
                
                let buildGradle = url.appendingPathComponent("app").appendingPathComponent("build.gradle")
                if FileManager.default.fileExists(atPath: buildGradle.path) {
                    logOutput += "✅ Found build.gradle\n"
                } else {
                    logOutput += "❌ Could not find build.gradle in app/ directory\n"
                }
            }
        }
    }
    
    private func buildAPK() {
        guard !projectPath.isEmpty else {
            logOutput = "Please select an Android project first\n"
            return
        }
        
        logOutput += "\n🛠️ Building APK...\n"
        
        runCommand(command: "./gradlew assembleDebug", in: projectPath) { output in
            DispatchQueue.main.async {
                self.logOutput += output
            }
        }
    }
    
    private func installAPK() {
        guard !projectPath.isEmpty else {
            logOutput = "Please select an Android project first\n"
            return
        }
        
        logOutput += "\n📱 Installing APK...\n"
        
        runCommand(command: "./gradlew installDebug", in: projectPath) { output in
            DispatchQueue.main.async {
                self.logOutput += output
            }
        }
    }
    
    private func runOnDevice() {
        guard !projectPath.isEmpty else {
            logOutput = "Please select an Android project first\n"
            return
        }
        
        logOutput += "\n🚀 Running on device...\n"
        
        runCommand(command: "./gradlew installDebug && adb shell am start -n \(getPackageName())/.MainActivity", in: projectPath) { output in
            DispatchQueue.main.async {
                self.logOutput += output
            }
        }
    }
    
    private func toggleLogs() {
        if isWatchingLogs {
            logProcess?.terminate()
            logProcess = nil
            logOutput += "\n⏹️ Stopped logcat\n"
        } else {
            logOutput += "\n📋 Starting logcat...\n"
            logProcess = Process()
            logProcess?.executableURL = URL(fileURLWithPath: "/usr/local/bin/adb")
            logProcess?.arguments = ["logcat", "-v", "time", "*:D"]
            
            let pipe = Pipe()
            logProcess?.standardOutput = pipe
            
            let outHandle = pipe.fileHandleForReading
            outHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if let string = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.logOutput += string
                    }
                }
            }
            
            do {
                try logProcess?.run()
            } catch {
                logOutput += "❌ Failed to start logcat: \(error.localizedDescription)\n"
                logProcess = nil
            }
        }
        
        isWatchingLogs.toggle()
    }
    
    private func getPackageName() -> String {
        // This is a simplified version. In a real app, you'd parse the build.gradle file
        // to get the actual package name.
        return "com.example.app"
    }
    
    private func runCommand(command: String, in directory: String, completion: @escaping (String) -> Void) {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryPath = directory
        process.standardOutput = pipe
        process.standardError = pipe
        
        let outHandle = pipe.fileHandleForReading
        outHandle.readabilityHandler = { pipe in
            if let line = String(data: pipe.availableData, encoding: .utf8) {
                if !line.isEmpty {
                    completion(line)
                }
            } else {
                print("Error decoding data: \(pipe.availableData)")
            }
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let error = "Command failed with status: \(process.terminationStatus)\n"
                completion(error)
            }
        } catch {
            completion("Failed to run command: \(error.localizedDescription)\n")
        }
    }
}

struct ActionButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

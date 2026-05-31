import Foundation

enum CommandLineConversion {
    static func runIfRequested() {
        let arguments = CommandLine.arguments
        guard arguments.count == 4, arguments[1] == "--convert" else {
            return
        }

        let videoURL = URL(fileURLWithPath: arguments[2])
        let outputURL = URL(fileURLWithPath: arguments[3], isDirectory: true)
        let semaphore = DispatchSemaphore(value: 0)
        var exitCode: Int32 = 0

        Task {
            do {
                let result = try await LivePhotoConverter().convert(
                    videoURL: videoURL,
                    outputDirectory: outputURL
                ) { progress in
                    FileHandle.standardError.write(Data(String(format: "progress %.2f\n", progress).utf8))
                }

                print(result.photoURL.path(percentEncoded: false))
                print(result.movieURL.path(percentEncoded: false))
            } catch {
                FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
                exitCode = 1
            }

            semaphore.signal()
        }

        semaphore.wait()
        Foundation.exit(exitCode)
    }
}

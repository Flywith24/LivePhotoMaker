import Foundation

enum CommandLineConversion {
    static func runIfRequested() {
        let arguments = CommandLine.arguments
        guard (arguments.count == 4 || arguments.count == 5), arguments[1] == "--convert" else {
            return
        }

        let videoURL = URL(fileURLWithPath: arguments[2])
        let outputURL = URL(fileURLWithPath: arguments[3], isDirectory: true)
        let coverURL = arguments.count == 5 ? URL(fileURLWithPath: arguments[4]) : nil
        let semaphore = DispatchSemaphore(value: 0)
        let exitState = CommandLineExitState()

        Task {
            do {
                let result = try await LivePhotoConverter().convert(
                    videoURL: videoURL,
                    outputDirectory: outputURL,
                    coverImageURL: coverURL
                ) { progress in
                    FileHandle.standardError.write(Data(String(format: "progress %.2f\n", progress).utf8))
                }

                print(result.photoURL.path(percentEncoded: false))
                print(result.movieURL.path(percentEncoded: false))
            } catch {
                FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
                exitState.setExitCode(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
        Foundation.exit(exitState.exitCode)
    }
}

private final class CommandLineExitState: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int32 = 0

    var exitCode: Int32 {
        lock.lock()
        let result = value
        lock.unlock()
        return result
    }

    func setExitCode(_ exitCode: Int32) {
        lock.lock()
        value = exitCode
        lock.unlock()
    }
}

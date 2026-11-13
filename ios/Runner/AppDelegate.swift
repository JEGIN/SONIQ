import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static var isFolderImporterRegistered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerFolderImporter(with: engineBridge.pluginRegistry)
  }

  private func registerFolderImporter(with registry: FlutterPluginRegistry) {
    guard !AppDelegate.isFolderImporterRegistered else { return }
    if !registry.hasPlugin("SoniqFolderImporterPlugin") {
      AppDelegate.isFolderImporterRegistered = true
      if let registrar = registry.registrar(forPlugin: "SoniqFolderImporterPlugin") {
        SoniqFolderImporterPlugin.register(with: registrar)
      }
    }
  }
}

class SoniqFolderImporterPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private var pendingResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.soniq.soniq/folder_importer",
      binaryMessenger: registrar.messenger()
    )
    let instance = SoniqFolderImporterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "importFolder" {
      self.pendingResult = result
      DispatchQueue.main.async {
        self.presentFolderPicker()
      }
    } else if call.method == "importFiles" {
      self.pendingResult = result
      DispatchQueue.main.async {
        self.presentFilePicker()
      }
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  private func presentFolderPicker() {
    guard let rootVC = getTopViewController() else {
      pendingResult?(FlutterError(code: "NO_ROOT_VC", message: "Cannot find root view controller", details: nil))
      pendingResult = nil
      return
    }

    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
    } else {
      picker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
    }
    picker.delegate = self
    picker.allowsMultipleSelection = false
    picker.modalPresentationStyle = .formSheet
    rootVC.present(picker, animated: true, completion: nil)
  }

  private func presentFilePicker() {
    guard let rootVC = getTopViewController() else {
      pendingResult?(FlutterError(code: "NO_ROOT_VC", message: "Cannot find root view controller", details: nil))
      pendingResult = nil
      return
    }

    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
    } else {
      picker = UIDocumentPickerViewController(documentTypes: ["public.audio"], in: .import)
    }
    picker.delegate = self
    picker.allowsMultipleSelection = true
    picker.modalPresentationStyle = .formSheet
    rootVC.present(picker, animated: true, completion: nil)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let completion = pendingResult else { return }
    pendingResult = nil

    guard let pickedURL = urls.first else {
      completion(0)
      return
    }

    // Run copying on background queue with security scoping & NSFileCoordinator
    DispatchQueue.global(qos: .userInitiated).async {
      let isDir: Bool
      var isDirObj: ObjCBool = false
      if FileManager.default.fileExists(atPath: pickedURL.path, isDirectory: &isDirObj) {
        isDir = isDirObj.boolValue
      } else {
        isDir = true
      }

      guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        DispatchQueue.main.async {
          completion(FlutterError(code: "NO_DOCS", message: "Documents directory not found", details: nil))
        }
        return
      }

      let targetFolder = docsURL.appendingPathComponent("SONGS")
      try? FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true, attributes: nil)

      let supportedExts = Set(["mp3", "m4a", "flac", "wav", "aac", "ogg", "alac", "aiff"])
      var count = 0

      if isDir {
        let isSecScoped = pickedURL.startAccessingSecurityScopedResource()
        defer {
          if isSecScoped {
            pickedURL.stopAccessingSecurityScopedResource()
          }
        }

        let coordinator = NSFileCoordinator()
        var error: NSError?
        coordinator.coordinate(readingItemAt: pickedURL, options: .withoutChanges, error: &error) { scopedURL in
          let keys: [URLResourceKey] = [.isRegularFileKey]
          guard let enumerator = FileManager.default.enumerator(
            at: scopedURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
          ) else { return }

          for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if supportedExts.contains(ext) {
              let relativePath = fileURL.path.replacingOccurrences(of: scopedURL.path, with: "")
              let destURL = targetFolder.appendingPathComponent(relativePath)
              let destFolder = destURL.deletingLastPathComponent()
              try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true, attributes: nil)

              if FileManager.default.fileExists(atPath: destURL.path) {
                try? FileManager.default.removeItem(at: destURL)
              }
              do {
                try FileManager.default.copyItem(at: fileURL, to: destURL)
                count += 1
              } catch {
                print("SONIQ_IOS: Copy failed for \(fileURL.lastPathComponent): \(error)")
              }
            }
          }
        }
      } else {
        // Individual audio files
        for fileURL in urls {
          let ext = fileURL.pathExtension.lowercased()
          if supportedExts.contains(ext) {
            let isSecScoped = fileURL.startAccessingSecurityScopedResource()
            defer {
              if isSecScoped {
                fileURL.stopAccessingSecurityScopedResource()
              }
            }

            let destURL = targetFolder.appendingPathComponent(fileURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destURL.path) {
              try? FileManager.default.removeItem(at: destURL)
            }
            do {
              try FileManager.default.copyItem(at: fileURL, to: destURL)
              count += 1
            } catch {
              print("SONIQ_IOS: Copy failed for \(fileURL.lastPathComponent): \(error)")
            }
          }
        }
      }

      DispatchQueue.main.async {
        completion(count)
      }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingResult?(0)
    pendingResult = nil
  }

  private func getTopViewController() -> UIViewController? {
    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow } ?? UIApplication.shared.windows.first { $0.isKeyWindow }

    var topVC = keyWindow?.rootViewController
    while let presented = topVC?.presentedViewController {
      topVC = presented
    }
    return topVC
  }
}

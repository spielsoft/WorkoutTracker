import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      self.enableFlutterSemanticsForMacOSAutomation(flutterViewController)
    }

    super.awakeFromNib()
  }

  private func enableFlutterSemanticsForMacOSAutomation(_ flutterViewController: FlutterViewController) {
    let engine = flutterViewController.engine
    let setSemanticsEnabled = Selector(("setSemanticsEnabled:"))
    guard engine.responds(to: setSemanticsEnabled) else {
      return
    }
    // FlutterMacOS exposes this runtime hook before it exposes a public
    // runner API for native AX automation clients.
    engine.setValue(true, forKey: "semanticsEnabled")

    let notifySemanticsEnabledChanged = Selector(("notifySemanticsEnabledChanged"))
    if flutterViewController.responds(to: notifySemanticsEnabledChanged) {
      flutterViewController.perform(notifySemanticsEnabledChanged)
    }
  }
}

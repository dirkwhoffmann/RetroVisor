import Cocoa

class PreferencesSplitViewController: NSSplitViewController {

    let main = NSStoryboard(name: "Main", bundle: nil)

    private lazy var generalVC: GeneralPreferencesViewController = {
        return main.instantiateController(withIdentifier: "GeneralPreferencesViewController") as! GeneralPreferencesViewController
    }()
    private lazy var shaderVC: ShaderPreferencesViewController = {
        return main.instantiateController(withIdentifier: "ShaderPreferencesViewController") as! ShaderPreferencesViewController
    }()
    private lazy var recorderVC: RecorderPreferencesViewController = {
        return main.instantiateController(withIdentifier: "RecorderPreferencesViewController") as! RecorderPreferencesViewController
    }()

    private var sidebarVC: SidebarViewController? {
        return splitViewItems.first?.viewController as? SidebarViewController
    }

    override func viewDidLoad() {

        super.viewDidLoad()
        sidebarVC?.selectionHandler = { [weak self] item in
            self?.showContent(for: item)
        }
    }

    private func showContent(for item: SidebarItem) {
        let newVC: NSViewController

        switch item.identifier.rawValue {
        case "general":
            newVC = generalVC // GeneralPreferencesViewController()
        case "shader":
            newVC = shaderVC //ShaderPreferencesViewController()
        case "recorder":
            newVC = recorderVC // RecorderPreferencesViewController()
        default:
            newVC = NSViewController()
        }

        /*
         // Replace content with animation
             if let window = self.view.window {
                 let targetSize = newVC.view.fittingSize
                 var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: targetSize))
                 frame.origin = window.frame.origin
                 frame.origin.y += window.frame.height - frame.height
                 window.setFrame(frame, display: true, animate: true)
             }
         */

        // Replace right pane
        print("Replace right pane")
        // Remove the old content pane
        removeSplitViewItem(splitViewItems[1])

        // Create a new split view item for the new content
        let newItem = NSSplitViewItem(viewController: newVC)
        addSplitViewItem(newItem)

    }
}

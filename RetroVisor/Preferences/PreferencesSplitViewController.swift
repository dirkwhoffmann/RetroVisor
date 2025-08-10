import Cocoa

class PreferencesSplitViewController: NSSplitViewController {

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
            newVC = GeneralPreferencesViewController()
        case "video":
            newVC = VideoPreferencesViewController()
        case "audio":
            newVC = AudioPreferencesViewController()
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
        splitViewItems[1].viewController = newVC

    }
}

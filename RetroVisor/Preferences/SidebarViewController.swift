import Cocoa

struct SidebarItem {
    let title: String
    let iconName: String // SF Symbol
    let identifier: NSUserInterfaceItemIdentifier
}

class SidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {

    @IBOutlet weak var outlineView: NSOutlineView!

    let items: [SidebarItem] = [
        SidebarItem(title: "General", iconName: "gearshape", identifier: .init("general")),
        SidebarItem(title: "Video", iconName: "video", identifier: .init("video")),
        SidebarItem(title: "Audio", iconName: "speaker.wave.2", identifier: .init("audio"))
    ]

    var selectionHandler: ((SidebarItem) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.selectionHighlightStyle = .sourceList
        outlineView.reloadData()

        // Select first item by default
        outlineView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return items.count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return items[index]
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let sidebarItem = item as? SidebarItem else { return nil }
        let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("SidebarCell"), owner: self) as? NSTableCellView
        cell?.textField?.stringValue = sidebarItem.title
        cell?.imageView?.image = NSImage(systemSymbolName: sidebarItem.iconName, accessibilityDescription: nil)
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let selectedIndex = outlineView.selectedRow
        if selectedIndex >= 0 {
            selectionHandler?(items[selectedIndex])
        }
    }
}

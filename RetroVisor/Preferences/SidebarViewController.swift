import Cocoa

struct SidebarItem {

    let title: String
    let iconName: String
    let identifier: NSUserInterfaceItemIdentifier
}

class SidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet weak var tableView: NSTableView!

    let items: [SidebarItem] = [
        SidebarItem(title: "General", iconName: "CategoryGeneral", identifier: .init("general")),
        SidebarItem(title: "Shader", iconName: "CategoryShader", identifier: .init("shader")),
        SidebarItem(title: "Recorder", iconName: "CategoryRecorder", identifier: .init("recorder"))
    ]

    var selectionHandler: ((SidebarItem) -> Void)?

    override func viewDidLoad() {

        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAutomaticRowHeights = false
        tableView.rowHeight = 48
        tableView.rowSizeStyle = .custom
        tableView.reloadData()

        // Select first item by default
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        let item = items[row]
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("SidebarCell"), owner: self) as? NSTableCellView

        cell?.textField?.stringValue = item.title
        cell?.imageView?.image = NSImage(named: item.iconName)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {

        let selectedIndex = tableView.selectedRow
        if selectedIndex >= 0 {
            selectionHandler?(items[selectedIndex])
        }
    }
}

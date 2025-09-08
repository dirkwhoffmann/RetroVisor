// -----------------------------------------------------------------------------
// This file is part of RetroVisor
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

import MetalKit
import MetalPerformanceShaders

@MainActor
struct Binding {
    
    let key: String
    let get: () -> Float
    let set: (Float) -> Void
    
    init(key: String, get: @escaping () -> Float, set: @escaping (Float) -> Void) {
        
        self.key = key
        self.get = get
        self.set = set
    }
}

@MainActor
class ShaderSetting {

    // Description of this setting
    var title: String

    // Parameters for numeric settings
    let range: ClosedRange<Double>?
    let step: Float

    // Parameters for enum settings
    let items: [(String,Int)]?

    // Optional help string
    let help: String?

    // Binding for the enable key
    private var enable: Binding?

    // Binding for the value key
    private var value: Binding?
    
    init(title: String = "",
         range: ClosedRange<Double>? = nil,
         step: Float = 0.01,
         items: [(String,Int)]? = nil,
         enable: Binding? = nil,
         value: Binding? = nil,
         help: String? = nil
        ) {

        self.title = title
        self.enable = enable
        self.value = value
        self.range = range
        self.step = step
        self.items = items
        self.help = help
    }
 
    var enableKey: String { enable?.key ?? "" }
    var valueKey: String { value?.key ?? "" }

    var enabled: Bool? {
        get { enable.map { $0.get() != 0 } }
        set { newValue.map { enable?.set($0.floatValue) } }
    }
                    
    var boolValue: Bool? {
        get { value.map { $0.get() != 0 } }
        set { newValue.map { value?.set($0.floatValue) } }
    }

    var int32Value: Int32? {
        get { value.map { Int32($0.get()) } }
        set { newValue.map { value?.set(Float($0)) } }
    }

    var intValue: Int? {
        get { value.map { Int($0.get()) } }
        set { newValue.map { value?.set(Float($0)) } }
    }

    var floatValue: Float? {
        get { value.map { $0.get() } }
        set { newValue.map { value?.set($0) } }
    }
}

@MainActor
class Group : ShaderSetting {

    // The cell view associated with this group
    var view: ShaderTableCellView?
    
    // The settings in this group
    var children: [ShaderSetting]
    
    // var count: Int { children.filter { $0.hidden() == false }.count }
    
    init(title: String = "",
         range: ClosedRange<Double>? = nil,
         step: Float = 0.01,
         items: [(String,Int)]? = nil,
         enable: Binding? = nil,
         value: Binding? = nil,
         help: String? = nil,
         hidden: @escaping () -> Bool = { false },
         _ children: [ShaderSetting]) {
        
        self.children = children
        super.init(title: title,
                   range: range,
                   step: step,
                   items: items,
                   enable: enable,
                   value: value,
                   help: help)
    }
    
    func findSetting(key: String) -> ShaderSetting? {
        
        // Check this setting's bindings
        if enableKey == key || valueKey == key { return self }
        
        // Recurse into children
        for child in children {
            if child.enableKey == key || child.valueKey == key { return child }
        }
        
        return nil
    }
    
    var dictionary: [String: String] {
        
        var result: [String: String] = [:]
        
        if enableKey != "" { result[enableKey] = (enabled ?? true) ? "1" : "0" }
        if valueKey != "" { result[valueKey] = String(floatValue ?? 0) }

        for child in children {
            if child.enableKey != "" { result[child.enableKey] = (child.enabled ?? true) ? "1" : "0" }
            if child.valueKey != "" { result[child.valueKey] = String(child.floatValue ?? 0) }
        }
        return result
    }
}

//
//  CatalystPluginImplementation.swift
//  SaneScanner-CatalystPlugin
//
//  Created by Stanislas Chevallier on 03/05/2021.
//  Copyright © 2021 Syan. All rights reserved.
//

import AppKit

@objc public class CatalystPluginImplementation: NSObject, CatalystPlugin {
    required public override init() {
    }
    
    private let fieldSize = NSSize(width: 230, height: 25)

    public func presentHostInputAlert(title: String, message: String, add: String, cancel: String, completion: (String) -> ()) {
        let alert = NSAlert()

        let addButton = alert.addButton(withTitle: add)
        let cancelButton = alert.addButton(withTitle: cancel)
        alert.messageText = title
        alert.informativeText = message

        let textField = NSTextField(frame: NSRect(origin: .zero, size: fieldSize))
        textField.stringValue = ""
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel

        alert.accessoryView = textField
        alert.window.initialFirstResponder = alert.accessoryView
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textField.nextKeyView = addButton
            cancelButton.nextKeyView = textField
        }

        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
            completion(textField.stringValue)
        }
    }
    
    public func presentAuthInputAlert(title: String, message: String, usernamePlaceholder: String, passwordPlaceholder: String, continue: String, remember: String, cancel: String, completion: (_ username: String?, _ password: String?, _ remember: Bool) -> ()) {

        let alert = NSAlert()

        let continueButton = alert.addButton(withTitle: `continue`)
        alert.addButton(withTitle: remember)
        let cancelButton = alert.addButton(withTitle: cancel)
        alert.messageText = title
        alert.informativeText = message

        let usernameField = NSTextField(frame: NSRect(x: 0, y: fieldSize.height + 5, width: fieldSize.width, height: fieldSize.height))
        usernameField.placeholderString = usernamePlaceholder
        usernameField.stringValue = ""
        usernameField.isBezeled = true
        usernameField.bezelStyle = .roundedBezel

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: fieldSize.width, height: fieldSize.height))
        passwordField.placeholderString = passwordPlaceholder
        passwordField.stringValue = ""
        passwordField.isBezeled = true
        passwordField.bezelStyle = .roundedBezel

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: fieldSize.width, height: fieldSize.height * 2 + 5))
        accessory.autoresizingMask = .width
        accessory.wantsLayer = true
        accessory.addSubview(usernameField)
        accessory.addSubview(passwordField)
        accessory.translatesAutoresizingMaskIntoConstraints = false
        accessory.setContentHuggingPriority(.required, for: .vertical)
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = usernameField
        
        usernameField.nextKeyView = passwordField
        passwordField.nextKeyView = continueButton
        cancelButton.nextKeyView = usernameField

        let rv = alert.runModal()
        let cancelled = rv == NSApplication.ModalResponse.alertThirdButtonReturn
        completion(cancelled ? nil : usernameField.stringValue, cancelled ? nil : passwordField.stringValue, rv == NSApplication.ModalResponse.alertSecondButtonReturn)
    }

    public func dropdown(options: [CatalystDropdownValueProtocol], selectedIndex: Int, disabled: Bool, changed: @escaping (CatalystDropdownValueProtocol) -> ()) -> CatalystView {
        let view = NSPopUpButton()

        if selectedIndex >= 0 && selectedIndex < options.count {
            view.addItem(withTitle: options[selectedIndex].title)
            view.selectItem(at: 0)
        }
        view.isEnabled = !disabled
        
        NotificationCenter.default.addObserver(forName: NSPopUpButton.willPopUpNotification, object: view, queue: .main) { _ in
            view.removeAllItems()
            view.addItems(withTitles: options.map(\.title))
            view.selectItem(at: selectedIndex >= 0 ? selectedIndex : -1)
        }
        NotificationCenter.default.addObserver(forName: NSMenu.didSendActionNotification, object: view.menu, queue: .main) { _ in
            changed(options[view.indexOfSelectedItem])
        }
        return CatalystViewImplementation(originalView: view).containerWithProperScaling
    }
    
    public func button(title: String, completion: @escaping () -> ()) -> CatalystView {
        let view = Button(title: title, target: nil, action: nil)
        view.pressedBlock = completion
        return CatalystViewImplementation(originalView: view).containerWithProperScaling
    }
}

private class Button: NSButton {
    var pressedBlock: (() -> ())? {
        didSet {
            target = self
            action = #selector(pressed)
        }
    }
    
    @objc private func pressed() {
        pressedBlock?()
    }
}


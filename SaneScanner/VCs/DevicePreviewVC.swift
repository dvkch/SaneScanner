//
//  DevicePreviewVC.swift
//  SaneScanner
//
//  Created by Stanislas Chevallier on 26/04/2021.
//  Copyright © 2021 Syan. All rights reserved.
//

import UIKit
import SaneSwift

class DevicePreviewVC: UIViewController {
    
    // MARK: ViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        
        #if targetEnvironment(macCatalyst)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "folder"), style: .plain, target: self, action: #selector(openFolderInFinderTap))
        #endif

        emptyStateView.backgroundColor = .background
        emptyStateLabel.autoAdjustsFontSize = true

        previewView.showScanButton = true
        
        separatorView.backgroundColor = .splitSeparator
        
        galleryThumbsView.backgroundColor = .background
        galleryThumbsView.scrollDirection = .vertical
        galleryThumbsView.parentViewController = self

        refresh()
    }
    
    // MARK: Properties
    var delegate: SanePreviewViewDelegate? {
        didSet {
            previewView?.delegate = delegate
        }
    }
    var device: Device? {
        didSet {
            previewView?.device = device
            refresh()
        }
    }

    // MARK: Views
    @IBOutlet private var emptyStateView: UIView!
    @IBOutlet private var emptyStateLabel: UILabel!
    @IBOutlet private var previewView: SanePreviewView!
    @IBOutlet private var separatorView: UIView!
    @IBOutlet private var separatorViewWidth: NSLayoutConstraint!
    @IBOutlet private var galleryThumbsView: GalleryThumbsView!

    // MARK: Actions
    #if targetEnvironment(macCatalyst)
    @objc private func openFolderInFinderTap() {
        UIApplication.shared.open(GalleryManager.shared.galleryFolder, options: [:], completionHandler: nil)
    }
    #endif
    
    // MARK: Content
    private func refresh() {
        updateEmptyState()

        guard device != nil else { return }
        previewView.refresh()
    }

    private func updateEmptyState() {
        guard isViewLoaded else { return }

        let text = NSMutableAttributedString()
        text.append("PREVIEW VC NO DEVICE TITLE".localized, font: .preferredFont(forTextStyle: .body), color: .normalText)
        text.append("\n\n", font: .preferredFont(forTextStyle: .subheadline), color: .normalText)
        text.append("PREVIEW VC NO DEVICE SUBTITLE".localized, font: .preferredFont(forTextStyle: .subheadline), color: .altText)
        emptyStateLabel.attributedText = text
        
        emptyStateView.isHidden = device != nil
        previewView.isHidden = device == nil
    }
    
    // MARK: Layout
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        #if targetEnvironment(macCatalyst)
        separatorViewWidth.constant = 1.5
        #else
        separatorViewWidth.constant = 1 / (view.window?.screen.scale ?? 1)
        #endif
    }
}
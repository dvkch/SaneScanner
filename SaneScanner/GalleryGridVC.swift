//
//  GalleryGridVC.swift
//  SaneScanner
//
//  Created by Stanislas Chevallier on 24/02/2019.
//  Copyright © 2019 Syan. All rights reserved.
//

import UIKit
import SVProgressHUD

class GalleryGridVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "GALLERY OVERVIEW TITLE".localized
        
        if #available(iOS 10.0, *) {
            emptyStateLabel.adjustsFontForContentSizeCategory = true
        }
        
        collectionViewLayout.maxSize = 320/3
        collectionViewLayout.margin = 2

        collectionView.collectionViewLayout = collectionViewLayout
        collectionView.registerCell(GalleryThumbnailCell.self, xib: false)
        
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(self.deleteButtonTap)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "PDF", style: .plain, target: self, action: #selector(self.pdfButtonTap(sender:))),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.shareButtonTap(sender:)))
        ]
        
        updateNavBarButtons()
        
        GalleryManager.shared.addDelegate(self)
    }
    
    // MARK: Properties
    private var items = [GalleryItem]() {
        didSet {
            updateEmptyState()
            collectionView.reloadData()
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        updateNavBarButtons()
    }

    // MARK: Views
    @IBOutlet private var emptyStateView: UIView!
    @IBOutlet private var emptyStateLabel: UILabel!
    private let collectionViewLayout = GridLayout()
    @IBOutlet private var collectionView: UICollectionView!
    
    // MARK: Actions
    #if DEBUG
    @objc private func addTestImagesButtonTap() {
        GalleryManager.shared.createRandomTestImages(count: 20)
    }
    #endif
    
    @objc private func deleteButtonTap() {
        guard let selected = collectionView.indexPathsForSelectedItems, !selected.isEmpty else { return }
        
        var title = "DIALOG TITLE DELETE SCAN".localized
        var message = "DIALOG MESSAGE DELETE SCAN".localized
        
        if selected.count > 1 {
            title   = "DIALOG TITLE DELETE SCANS".localized
            message = String(format: "DIALOG MESSAGE DELETE SCANS %d".localized, selected.count)
        }
        
        DLAVAlertView(title: title, message: message, delegate: nil, cancel: "ACTION CANCEL".localized, others: ["ACTION DELETE".localized])
            .show { (alert, index) in
                guard index != alert?.cancelButtonIndex else { return }
                
                SVProgressHUD.show()
                selected.forEach { (indexPath) in
                    GalleryManager.shared.deleteItem(self.items[indexPath.item])
                }
                SVProgressHUD.dismiss()
                self.setEditing(false, animated: true)
        }
    }
    
    @objc private func pdfButtonTap(sender: UIBarButtonItem) {
        guard let selected = collectionView.indexPathsForSelectedItems, !selected.isEmpty else { return }
        
        SVProgressHUD.show()
        
        // needed to let SVProgressHUD appear, even if PDF is generated on main thread
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.shareSelectedItemsAsPDF(sender: sender)
        }
    }
    
    @objc private func shareButtonTap(sender: UIBarButtonItem) {
        let urls = self.selectedURLs()
        guard !urls.isEmpty else { return }
        
        UIActivityViewController.showForURLs(urls, from: sender, presentingVC: self, completion: nil)
    }
    
    // MARK: Sharing
    private func selectedURLs() -> [URL] {
        return (collectionView.indexPathsForSelectedItems ?? [])
            .sorted()
            .compactMap { self.items[$0.row].URL }
    }
    
    private func shareSelectedItemsAsPDF(sender: UIBarButtonItem) {
        let urls = self.selectedURLs()
        guard !urls.isEmpty else { return }
        
        let tempURL = GalleryManager.shared.tempPdfFileUrl()
        
        do {
            try PDFGenerator.generatePDF(destination: tempURL, images: selectedURLs(), aspectRatio: 210 / 297, jpegQuality: 0.9, fixedPageSize: true)
            SVProgressHUD.dismiss()
        }
        catch {
            SVProgressHUD.showError(withStatus: error.localizedDescription)
            return
        }
        
        UIActivityViewController.showForURLs([tempURL], from: sender, presentingVC: self) {
            // is called when the interaction with the PDF is done. It's either been copied, imported,
            // displayed, shared or printed, but we can dispose of it
            GalleryManager.shared.deleteTempPDF()
        }
    }
    
    @objc private func editButtonTap() {
        self.setEditing(!isEditing, animated: true)
    }

    // MARK: Content
    private func updateEmptyState() {
        let text = NSMutableAttributedString()
        text.sy_appendString("GALLERY EMPTY TITLE".localized, font: .systemFont(ofSize: 17), color: .darkGray)
        text.sy_appendString("\n\n", font: .systemFont(ofSize: 15), color: .gray)
        text.sy_appendString("GALLERY EMPTY SUBTITLE".localized, font: .systemFont(ofSize: 15), color: .gray)
        emptyStateLabel.attributedText = text
        
        emptyStateView.isHidden = !items.isEmpty
        collectionView.isHidden = items.isEmpty
    }
    
    private func updateNavBarButtons() {
        var buttons = [UIBarButtonItem]()
        
        if isEditing {
            buttons.append(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.editButtonTap)))
        } else {
            buttons.append(UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(self.editButtonTap)))
        }
        
        #if DEBUG
        buttons.append(UIBarButtonItem(title: "Add test images", style: .plain, target: self, action: #selector(self.addTestImagesButtonTap)))
        #endif
        
        navigationItem.rightBarButtonItems = buttons
    }
}

extension GalleryGridVC : UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCell(GalleryThumbnailCell.self, for: indexPath)
        cell.item = items[indexPath.row]
        return cell
    }
}

extension GalleryGridVC : UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let imagesVC = GalleryImagesVC()
        imagesVC.initialIndex = indexPath.row
        navigationController?.pushViewController(imagesVC, animated: true)
    }
}

extension GalleryGridVC : GalleryManagerDelegate {
    func galleryManager(_ manager: GalleryManager, didCreate thumbnail: UIImage, for item: GalleryItem) { }
    
    func galleryManager(_ manager: GalleryManager, didUpdate items: [GalleryItem], newItems: [GalleryItem], removedItems: [GalleryItem]) {
        self.items = items
    }
}

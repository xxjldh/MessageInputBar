
import UIKit

open class AttachmentManager: NSObject, InputPlugin {
  
    public enum Attachment {
        case image(UIImage)
        case url(URL)
        case data(Data)
    }
    
    // MARK: - Properties [Public]
    
    /// A protocol that can recieve notifications from the `AttachmentManager`
    open weak var delegate: AttachmentManagerDelegate?
    
    /// A protocol to passes data to the `AttachmentManager`
    open weak var dataSource: AttachmentManagerDataSource?
    
    open lazy var attachmentView: AttachmentCollectionView = { [weak self] in
        let attachmentView = AttachmentCollectionView()
        attachmentView.dataSource = self
        attachmentView.delegate = self
        return attachmentView
    }()
    
    /// The attachments that the managers holds
    private(set) public var attachments = [Attachment]() { didSet { reloadData() } }
    
    /// A flag you can use to determine if you want the manager to be always visible
    open var isPersistent = false { didSet { attachmentView.reloadData() } }
    
    /// A flag to determine if the AddAttachmentCell is visible
    open var showAddAttachmentCell = true { didSet { attachmentView.reloadData() } }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    // MARK: - InputManager
    
    open func reloadData() {
        attachmentView.reloadData()
        delegate?.attachmentManager(self, didReloadTo: attachments)
        delegate?.attachmentManager(self, shouldBecomeVisible: attachments.count > 0 || isPersistent)
    }
    
    /// Invalidates the `AttachmentManagers` session by removing all attachments
    open func invalidate() {
        attachments = []
    }
    
    /// Appends the object to the attachments
    ///
    /// - Parameter object: The object to append
    open func handleInput(of object: AnyObject) -> Bool {
        let attachment: Attachment
        if let image = object as? UIImage {
            attachment = .image(image)
        } else if let url = object as? URL {
            attachment = .url(url)
        } else if let data = object as? Data {
            attachment = .data(data)
        } else {
            return false
        }
        insertAttachment(attachment, at: attachments.count)
        return true
    }
    
    // MARK: - API [Public]
    
    /// Performs an animated insertion of an attachment at an index
    ///
    /// - Parameter index: The index to insert the attachment at
    open func insertAttachment(_ attachment: Attachment, at index: Int) {
        
        attachmentView.performBatchUpdates({
            self.attachments.insert(attachment, at: index)
            self.attachmentView.insertItems(at: [IndexPath(row: index, section: 0)])
        }, completion: { success in
            self.attachmentView.reloadData()
            self.delegate?.attachmentManager(self, didInsert: attachment, at: index)
            self.delegate?.attachmentManager(self, shouldBecomeVisible: self.attachments.count > 0 || self.isPersistent)
        })
    }
    
    /// Performs an animated removal of an attachment at an index
    ///
    /// - Parameter index: The index to remove the attachment at
    open func removeAttachment(at index: Int) {
        
        let attachment = attachments[index]
        attachmentView.performBatchUpdates({
            self.attachments.remove(at: index)
            self.attachmentView.deleteItems(at: [IndexPath(row: index, section: 0)])
        }, completion: { success in
            self.attachmentView.reloadData()
            self.delegate?.attachmentManager(self, didRemove: attachment, at: index)
            self.delegate?.attachmentManager(self, shouldBecomeVisible: self.attachments.count > 0 || self.isPersistent)
        })
    }
    
}

extension AttachmentManager: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - UICollectionViewDelegate
    
    final public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row == attachments.count {
            delegate?.attachmentManager(self, didSelectAddAttachmentAt: indexPath.row)
            delegate?.attachmentManager(self, shouldBecomeVisible: attachments.count > 0 || isPersistent)
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    final public func numberOfItems(inSection section: Int) -> Int {
        return 1
    }
    
    final public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return attachments.count + (showAddAttachmentCell ? 1 : 0)
    }
    
    final public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.row == attachments.count && showAddAttachmentCell {
            return addAttachmentCell(in: collectionView, at: indexPath)
        }
        
        let attachment = attachments[indexPath.row]
        
        if let cell = dataSource?.attachmentManager(self, cellFor: attachment, at: indexPath.row) {
            return cell
        } else {
            
            // Only images are supported by default
            switch attachment {
            case .image(let image):
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageAttachmentCell.reuseIdentifier, for: indexPath) as? ImageAttachmentCell else {
                    fatalError()
                }
                cell.attachment = attachment
                cell.indexPath = indexPath
                cell.manager = self
                cell.imageView.image = image
                return cell
            default:
                return collectionView.dequeueReusableCell(withReuseIdentifier: AttachmentCell.reuseIdentifier, for: indexPath) as! AttachmentCell
            }
            
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    final public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var height = attachmentView.intrinsicContentHeight
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            height -= (layout.sectionInset.bottom + layout.sectionInset.top + collectionView.contentInset.top + collectionView.contentInset.bottom)
        }
        return CGSize(width: height, height: height)
    }
    
    private func addAttachmentCell(in collectionView: UICollectionView, at indexPath: IndexPath) -> AttachmentCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AttachmentCell.reuseIdentifier, for: indexPath) as? AttachmentCell else {
            fatalError()
        }
        cell.deleteButton.isHidden = true
        // Draw a plus
        let frame = CGRect(origin: CGPoint(x: cell.bounds.origin.x,
                                           y: cell.bounds.origin.y),
                           size: CGSize(width: cell.bounds.width - cell.padding.left - cell.padding.right,
                                        height: cell.bounds.height - cell.padding.top - cell.padding.bottom))
        let strokeWidth: CGFloat = 3
        let length: CGFloat = frame.width / 2
        let vLayer = CAShapeLayer()
        vLayer.path = UIBezierPath(roundedRect: CGRect(x: frame.midX - (strokeWidth / 2),
                                                       y: frame.midY - (length / 2),
                                                       width: strokeWidth,
                                                       height: length), cornerRadius: 5).cgPath
        vLayer.fillColor = UIColor.lightGray.cgColor
        let hLayer = CAShapeLayer()
        hLayer.path = UIBezierPath(roundedRect: CGRect(x: frame.midX - (length / 2),
                                                       y: frame.midY - (strokeWidth / 2),
                                                       width: length,
                                                       height: strokeWidth), cornerRadius: 5).cgPath
        hLayer.fillColor = UIColor.lightGray.cgColor
        cell.containerView.layer.addSublayer(vLayer)
        cell.containerView.layer.addSublayer(hLayer)
        return cell
    }
}

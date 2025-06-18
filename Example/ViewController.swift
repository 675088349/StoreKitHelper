//
//  ViewController.swift
//  TestZoom
//
//  Created by admin on 2025/6/18.
//

import UIKit

class ViewController: UIViewController {
    
    private var scrollView: UIScrollView!
    private var collectionView: UICollectionView!
    private var longPressGesture: UILongPressGestureRecognizer!
    
    // 示例图片数据
    private let imageNames = ["image1", "image2", "image3", "image4", "image5"]
    
    // 长按相关属性
    private var longPressLocation: CGPoint = .zero
    private var isZooming = false
    private var initialZoomScale: CGFloat = 1.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 设置ScrollView作为容器
        scrollView = UIScrollView(frame: view.bounds)
        scrollView.backgroundColor = .black
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = true
        scrollView.bouncesZoom = true
        
        // 设置CollectionView
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // 注册cell
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: "ImageCell")
        
        // 设置从右到左的语义
        collectionView.semanticContentAttribute = .forceRightToLeft
        
        // 将CollectionView添加到ScrollView中
        scrollView.addSubview(collectionView)
        scrollView.contentSize = collectionView.frame.size
        
        view.addSubview(scrollView)
    }
    
    private func setupGestures() {
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        scrollView.addGestureRecognizer(longPressGesture)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: scrollView)
        
        switch gesture.state {
        case .began:
            // 保存转换后的collectionView坐标，确保坐标系一致
            longPressLocation = scrollView.convert(location, to: collectionView)
            startZooming(at: location)
            updateZoomPosition(to: gesture.location(in: scrollView))
        case .changed:
            print("contentOffset x = \(scrollView.contentOffset.x)")
            if isZooming {
                updateZoomPosition(to: gesture.location(in: scrollView), sensitivityFactor: 1)
//                updateZoomPosition(to: gesture.location(in: scrollView), sensitivityFactor)
            }
            
        case .ended, .cancelled:
            endZooming()
            
        default:
            break
        }
    }
    
    private func startZooming(at location: CGPoint) {
        isZooming = true
        initialZoomScale = scrollView.zoomScale
        
        // 禁用CollectionView的滚动，防止与缩放冲突
        collectionView.isScrollEnabled = false
        
        // 计算缩放中心点
        let zoomScale: CGFloat = min(2.0, scrollView.maximumZoomScale)
        
        // 计算缩放后要显示的区域
        let zoomRect = calculateZoomRect(for: location, with: zoomScale)
        
        // 执行缩放
        scrollView.zoom(to: zoomRect, animated: true)
    }
    
    private func calculateZoomRect(for location: CGPoint, with zoomScale: CGFloat) -> CGRect {
        let zoomWidth = scrollView.bounds.width / zoomScale
        let zoomHeight = scrollView.bounds.height / zoomScale
        
        // 将ScrollView坐标转换为CollectionView坐标
        let collectionViewLocation = scrollView.convert(location, to: collectionView)
        
        let zoomX = collectionViewLocation.x - zoomWidth / 2
        let zoomY = collectionViewLocation.y - zoomHeight / 2
        
        return CGRect(x: zoomX, y: zoomY, width: zoomWidth, height: zoomHeight)
    }
    
    private func updateZoomPosition(to location: CGPoint, sensitivityFactor: CGFloat = 1) {
        guard isZooming else { return }
        
        // 转换当前位置到collectionView坐标系
        let collectionViewLocation = scrollView.convert(location, to: collectionView)
        
        // 计算移动的偏移量（longPressLocation已经是collectionView坐标）
        // 添加放大系数，增强滑动响应
        let deltaX = (collectionViewLocation.x - longPressLocation.x) * sensitivityFactor
        let deltaY = (collectionViewLocation.y - longPressLocation.y) * sensitivityFactor
        
        // 更新ScrollView的contentOffset
        var newOffset = scrollView.contentOffset
        newOffset.x -= deltaX
        newOffset.y -= deltaY
        
        // 限制在有效范围内
        let maxOffsetX = max(0, scrollView.contentSize.width * scrollView.zoomScale - scrollView.bounds.width)
        let maxOffsetY = max(0, scrollView.contentSize.height * scrollView.zoomScale - scrollView.bounds.height)
        
        newOffset.x = max(0, min(newOffset.x, maxOffsetX))
        newOffset.y = max(0, min(newOffset.y, maxOffsetY))
        
        scrollView.contentOffset = newOffset
        // 更新longPressLocation为当前的collectionView坐标
        longPressLocation = collectionViewLocation
        
        print("contentOffset x = \(newOffset.x)")
    }
    
    private func endZooming() {
        isZooming = false
        
        // 恢复CollectionView的滚动
        collectionView.isScrollEnabled = true
        
        // 恢复初始缩放比例
        scrollView.setZoomScale(initialZoomScale, animated: true)
    }
    

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        collectionView.frame = scrollView.bounds
        scrollView.contentSize = collectionView.frame.size
    }
}

// MARK: - UICollectionViewDataSource
extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageNames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCell
        
        // 这里使用系统图片作为示例，实际使用时替换为你的图片
        let imageName = "photo.fill" // 使用SF Symbols作为示例
        cell.configure(with: UIImage(systemName: imageName))
        
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension ViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
}

// MARK: - UIScrollViewDelegate
extension ViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return collectionView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 缩放时保持CollectionView居中
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        collectionView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                                       y: scrollView.contentSize.height * 0.5 + offsetY)
    }
}

// MARK: - ImageCell
class ImageCell: UICollectionViewCell {
    let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        contentView.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    func configure(with image: UIImage?) {
        imageView.image = image
    }
}


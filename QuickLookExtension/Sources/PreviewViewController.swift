//
//  PreviewViewController.swift
//  PMDQuickLook
//
//  Created by mtakagi on 2026/05/30.
//

import Cocoa
import Quartz
import MetalKit

class PreviewViewController: NSViewController, QLPreviewingController {
    
    var mtkView: MTKView!
    var renderer: Renderer!
    
    override func loadView() {
        // QuickLookのウィンドウ全体をMetal用のビューにする
        mtkView = MTKView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        self.view = mtkView
    }
    
    // Finderでスペースキーが押され、ファイルがプレビューされる瞬間に呼ばれる関数
    func preparePreviewOfFile(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            completionHandler(NSError(domain: "MetalError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal Deviceが見つかりません"]))
            return
        }
        mtkView.device = device
        
        // Finderから渡された `.pmd` ファイルの url を Renderer に渡す！
        if let newRenderer = Renderer(metalKitView: mtkView, modelUrl: url) {
            renderer = newRenderer
            renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.bounds.size)
            mtkView.delegate = renderer
            
            // 準備完了をシステムに知らせる
            completionHandler(nil)
        } else {
            completionHandler(NSError(domain: "RendererError", code: 2, userInfo: [NSLocalizedDescriptionKey: "モデルの読み込みに失敗しました"]))
        }
    }
}

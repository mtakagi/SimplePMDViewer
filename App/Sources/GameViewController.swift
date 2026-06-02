//
//  GameViewController.swift
//  metal-proj macOS
//
//  Created by mtakagi on 2025/10/20.
//

import Cocoa
import MetalKit
import UniformTypeIdentifiers // UTTypeを使うために必要

class GameViewController: NSViewController {

    var mtkView: MTKView!
    var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. MTKViewの取得（StoryboardでViewのクラスをMTKViewにしている前提）
        guard let view = self.view as? MTKView else {
            print("ViewがMTKViewではありません")
            return
        }
        self.mtkView = view
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal Deviceが見つかりません")
            return
        }
        self.mtkView.device = device

        // 2. 画面の左下に「ファイルを開く」ボタンをプログラムから配置する
        setupOpenButton()
    }

    // MARK: - UI Setup
    private func setupOpenButton() {
        let button = NSButton(title: "PMDを開く", target: self, action: #selector(openFileDialog))
        // 画面の左下に配置
        button.frame = NSRect(x: 20, y: 20, width: 120, height: 32)
        // 3D描画の上にボタンを表示するため、レイヤーを設定
        button.wantsLayer = true
        self.view.addSubview(button)
    }

    // MARK: - File Handling
    @objc private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.message = "読み込むPMDファイルを選択してください"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        // 拡張子 .pmd のみを許可する
        if #available(macOS 11.0, *) {
            if let type = UTType(filenameExtension: "pmd") {
                panel.allowedContentTypes = [type]
            }
        } else {
            panel.allowedFileTypes = ["pmd"]
        }

        // ダイアログを表示
        panel.beginSheetModal(for: self.view.window!) { [weak self] result in
            if result == .OK, let url = panel.url {
                self?.loadModel(at: url)
            }
        }
    }

    private func loadModel(at url: URL) {
        // 選択されたURLを使ってRendererを（再）作成する
        if let newRenderer = Renderer(metalKitView: self.mtkView, modelUrl: url) {
            self.renderer = newRenderer
            self.renderer.mtkView(self.mtkView, drawableSizeWillChange: self.mtkView.bounds.size)
            self.mtkView.delegate = self.renderer
            
            print("モデルの読み込みに成功しました: \(url.lastPathComponent)")
        } else {
            // 読み込み失敗時のアラート
            let alert = NSAlert()
            alert.messageText = "エラー"
            alert.informativeText = "PMDファイルの読み込みに失敗しました。"
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
}

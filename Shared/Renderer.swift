//
//  Renderer.swift
//  SimplePMDViewer Shared
//
//  Created by mtakagi on 2025/10/20.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate {

    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    
    // PMDモデルのデータ
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    
    let materials: [PMDMaterial]
    let textures: [MTLTexture?]

    var uniformBuffer: MTLBuffer!
    var projectionMatrix = matrix_float4x4()
    
    @MainActor
    init?(metalKitView: MTKView, modelUrl: URL) {
        // 1. まずデバイスとキューを確保
        let device = metalKitView.device!
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        self.device = device

        // 画面のフォーマット設定
        metalKitView.colorPixelFormat = .bgra8Unorm_srgb
        metalKitView.depthStencilPixelFormat = .depth32Float_stencil8
        metalKitView.clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = .less
        depthStateDescriptor.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor:depthStateDescriptor)!

        // 2. パイプライン（設計図）の作成
        let mtlVertexDescriptor = Renderer.buildPMDVertexDescriptor()
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "vertexShader"),
              let fragmentFunction = library.makeFunction(name: "fragmentShader") else { return nil }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        guard let pState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else { return nil }
        self.pipelineState = pState
        
        // 3. Uniformバッファの作成
        self.uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: .storageModeShared)
        
        // 4. PMDモデルの読み込みとバッファ化（super.initの前に行う）
        guard let pmdData = try? Renderer.parsePMDModel(url: modelUrl, device: device) else {
            print("PMDモデルの読み込みに失敗しました。ファイル名などを確認してください。")
            return nil
        }

        // 読み込んだデータを自身のプロパティにセット
        self.vertexBuffer = pmdData.vertexBuffer
        self.indexBuffer = pmdData.indexBuffer
        
        self.materials = pmdData.materials
        
        let textureLoader = MTKTextureLoader(device: device)
        let url = modelUrl.deletingLastPathComponent()
        var cachedTextures: [String: MTLTexture] = [:]
        
        self.textures = materials.map { material -> MTLTexture? in
            if material.textureFilePath.isEmpty {
                return nil
            }
            
            let mainPath = material.textureFilePath.components(separatedBy: "*").first ?? material.textureFilePath
            
            if let texture = cachedTextures[mainPath] {
                return texture
            }
            
            let textureUrl = url.appendingPathComponent(mainPath)

            if let texture = try? textureLoader.newTexture(URL: textureUrl, options: [.origin : MTKTextureLoader.Origin.topLeft]) {
                cachedTextures[mainPath] = texture
                
                return texture
            }
            
            return nil
        }
        
        // すべての準備が整ったので親クラスを初期化
        super.init()
    }

    // クラスメソッドにして self に依存せずPMDを解析できるようにする
    class func parsePMDModel(url: URL, device: MTLDevice) throws -> (vertexBuffer: MTLBuffer, indexBuffer: MTLBuffer, materials: [PMDMaterial]) {
        var reader = try BinaryReader(url: url)
        
        // ヘッダーを読み飛ばす
        _ = try PMDHeader(reader: &reader)
        
        // 頂点の読み込み
        let vertexCount = Int(reader.readUInt32LE())
        let vertices: [PMDVertex] = try reader.readArray(count: vertexCount)
        
        // インデックスの読み込み
        let indexCount = Int(reader.readUInt32LE())
        let indices: [UInt16] = try reader.readArray(count: indexCount)
        
        // マテリアルの読み込み
        let materialCount = Int(reader.readUInt32LE())
        let materials: [PMDMaterial] = try reader.readArray(count: materialCount)
        
        // バッファの生成
        guard let vBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<PMDVertex>.stride * vertexCount, options: []),
              let iBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indexCount, options: []) else {
            // エラーハンドリング（簡易的）
            throw NSError(domain: "PMDError", code: -1, userInfo: nil)
        }
        
        return (vBuffer, iBuffer, materials)
    }

    // PMDのデータ構造に合わせた頂点レイアウト
    class func buildPMDVertexDescriptor() -> MTLVertexDescriptor {
        let posOffset = MemoryLayout.offset(of: \PMDVertex.position)!
        let norOffset = MemoryLayout.offset(of: \PMDVertex.normal)!
        let uvOffset  = MemoryLayout.offset(of: \PMDVertex.uv)!
        let descriptor = MTLVertexDescriptor()
        
        // 0番: Position (Float3 = 12バイト)
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].offset = posOffset
        descriptor.attributes[0].bufferIndex = 0
        
        // 1番: Normal (Float3 = 12バイト)
        descriptor.attributes[1].format = .float3
        descriptor.attributes[1].offset = norOffset
        descriptor.attributes[1].bufferIndex = 0
        
        // 2番: UV (Float2 = 8バイト)
        descriptor.attributes[2].format = .float2
        descriptor.attributes[2].offset = uvOffset
        descriptor.attributes[2].bufferIndex = 0

        // PMDVertexの総サイズをストライドに設定
        descriptor.layouts[0].stride = MemoryLayout<PMDVertex>.stride
        descriptor.layouts[0].stepRate = 1
        descriptor.layouts[0].stepFunction = .perVertex
        
        return descriptor
    }

    // 描画処理のメインループ
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)

        // バッファをシェーダーに渡す
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)

        // PMDはマテリアルごとに使うインデックスの数が決まっているので、ループして少しずつ描画する
        var indexOffset = 0
        for (i, material) in materials.enumerated() {
            let drawCount = Int(material.indicesNum)
            var diffuse = SIMD4<Float>(material.diffuse, material.alpha)
            
            renderEncoder.setFragmentTexture(textures[i], index: 0)
            renderEncoder.setFragmentBytes(&diffuse, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
                        
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: drawCount,
                indexType: .uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: indexOffset * MemoryLayout<UInt16>.stride
            )
            
            // 次のマテリアルの開始位置へオフセットを進める
            indexOffset += drawCount
        }

        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
    }
    
    // 画面サイズが変わったときの処理
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65), aspectRatio: aspect, nearZ: 1.0, farZ: 500.0)
        var uniforms = Uniforms()
        uniforms.projectionMatrix = projectionMatrix
        // Y軸回転
        let modelMatrix = matrix4x4_rotation(radians: .pi, axis: SIMD3<Float>(0, 1, 0))
        // PMDモデルは大きいことが多いので、少し遠くから映す（Zを-30などに設定）
        let viewMatrix = matrix4x4_translation(0.0, -10.0, -20.0)
        uniforms.modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        
        // 計算結果をバッファに書き込む
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.size)
    }
}

func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}

//
//  EverythingController.swift
//  dataflow-toy
//
//  Created by Joe Landers on 25.06.21.
//

import Cocoa

class EverythingController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}


extension CGPoint {
    static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
}

extension NSView {
    var center: CGPoint { return CGPoint(x: frame.midX, y: frame.midY) }
}

extension NSRect {
    var center: CGPoint { return CGPoint(x: midX, y: midY) }
}

class Vertex: NSView {
    weak var rectangle: Rectangle?
    var circlePath: NSBezierPath = NSBezierPath()
    
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        NSColor.black.set()
        circlePath.lineWidth = 1.0
        circlePath.appendOval(in: CGRect(x:2.5, y:2.5, width: 5.0, height:5.0))
        circlePath.fill()
        circlePath.stroke()

        rectangle?.everything?.needsDisplay = true
    }

}

let rectangleTypes = [
    "gain": [
        "name": "gain",
        "inlets": ["input"],
        "outlets": ["output"],
    ],
    "LPF": [
        "name": "LPF",
        "inlets": ["input", "freq", "res"],
        "outlets": ["output"],
    ]
]

let initialRectangles = ["gain", "gain", "LPF", "LPF"]


class Rectangle: NSView {
    weak var everything: Everything?
    var descriptor: [String: Any]?
    var selected = false
    var inlets: [Vertex] = []
    var outlets: [Vertex] = []
    var labels: [NSTextField] = []
    
    override func mouseDown(with event: NSEvent) {
        NSLog("Rectangle mouseDown \(ObjectIdentifier(self)) \(event.locationInWindow)")
    }
    
    override func mouseUp(with event: NSEvent) {
        NSLog("Rectangle mouseUp   \(ObjectIdentifier(self)) \(event.locationInWindow)")
    }

    @IBInspectable var color: NSColor = .clear {
        didSet { layer?.backgroundColor = color.cgColor }
    }
    
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)
        if selected {
            NSColor.lightGray.set()
        } else {
            NSColor.gray.set()
        }
        
        self.layer?.cornerRadius = 5.0
        NSBezierPath(rect: dirtyRect).fill()
        
        NSColor.lightGray.set()
        NSBezierPath(rect: CGRect(x:0, y:110, width: 80, height: 10)).fill()

    }
    
    override func viewDidMoveToSuperview() {
        addGestureRecognizer(NSPanGestureRecognizer(target: self, action: #selector(pan)))

        guard let descInlets = descriptor?["inlets"] as? [String] else {
            return
        }
        guard let descOutlets = descriptor?["outlets"] as? [String] else {
            return
        }
        for case let (i, inletName) in descInlets.enumerated() {
            let inlet = Vertex(frame: convert(CGRect(x:-5, y:-5 + 30*(i+1), width:10, height:10), to: superview))
            everything?.vertexes.append(inlet)
            self.inlets.append(inlet)
            inlet.rectangle = self
            superview?.addSubview(inlet)
            
            let label = NSTextField(frame: convert(CGRect(x:5, y:-5 + 30*(i+1), width:30, height:10), to: superview))
            label.font = .systemFont(ofSize: 8)
            label.stringValue = inletName
            label.isBezeled = false
            label.isEditable = false
            label.drawsBackground = false
            superview?.addSubview(label)
            labels.append(label)
        }
        
        for case let (i, outletName) in descOutlets.enumerated() {
            let outlet = Vertex(frame: convert(CGRect(x:75, y:-5 + 30*(i+1), width:10, height:10), to: superview))
            everything?.vertexes.append(outlet)
            self.outlets.append(outlet)
            outlet.rectangle = self
            superview?.addSubview(outlet)
            
            let label = NSTextField(frame: convert(CGRect(x:45, y:-5 + 30*(i+1), width:30, height:10), to: superview))
            label.alignment = .right
            label.font = .systemFont(ofSize: 8)
            label.stringValue = outletName
            label.isBezeled = false
            label.isEditable = false
            label.drawsBackground = false
            superview?.addSubview(label)
            labels.append(label)
        }
        
        let label = NSTextField(frame: convert(CGRect(x:25, y:110, width:30, height:10), to: superview))
        label.alignment = .center
        label.font = .systemFont(ofSize: 8)
        label.stringValue = descriptor?["name"] as? String ?? ""
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        superview?.addSubview(label)
        labels.append(label)
    }
    
    @objc func pan(_ gesture: NSPanGestureRecognizer) {
        let point = gesture.translation(in: self)
        if everything!.selectedRectangles.count > 0 {
            for rectangle in everything!.selectedRectangles {
                rectangle.frame.origin += point
                for inlet in rectangle.inlets {
                    inlet.frame.origin += point
                }
                for outlet in rectangle.outlets {
                    outlet.frame.origin += point
                }
                for label in rectangle.labels {
                    label.frame.origin += point
                }
            }
        } else {
            frame.origin += point
            for inlet in inlets {
                inlet.frame.origin += point
            }
            for outlet in outlets {
                outlet.frame.origin += point
            }
            for label in labels {
                label.frame.origin += point
            }
        }
        gesture.setTranslation(.zero, in: self)
        everything?.drawGuidePaths()
    }
}

struct VertexPair: Hashable {
    let start: Vertex
    let finish: Vertex
}

class Everything: NSView {
    var rectangles: [Rectangle] = []
    var selectedRectangles: [Rectangle] = []
    var vertexes: [Vertex] = []
    let curvesLayer = CALayer()
    var shapeLayers : [CAShapeLayer] = []
    
    var unfinishedPath: CGMutablePath? = CGMutablePath()
    var unfinishedStart: NSPoint? = nil
    var unfinishedStop: NSPoint? = nil
    var unfinishedEdgeShapeLayer: CAShapeLayer? = CAShapeLayer()
    
    var selectionStart: NSPoint? = nil
    var selectionStop: NSPoint? = nil
    var selectionRect: CGRect? = nil
    var selectionShapeLayer: CAShapeLayer? = nil

    var unfinishedStartVertex: Vertex?
    
    var vertexPairs: [VertexPair] = []
    var vertexPairsToShapeLayers : [(VertexPair): CAShapeLayer] = [:]
    
    var guidePathsLayer = CALayer()
    var vertexesToGuidePathShapeLayers: [Vertex: CAShapeLayer] = [:]
    
    override func mouseDown(with event: NSEvent) {
        for rectangle in selectedRectangles {
            rectangle.selected = false
            rectangle.needsDisplay = true
        }
        selectedRectangles = []
        selectionRect = nil
        selectionStart = nil
        selectionStop = nil
        
        let target = hitTest(convert(event.locationInWindow, from: nil))
        NSLog("everything mouseDown hitTest: \(target)")
        if let targetVertex = target as? Vertex {
            unfinishedStart = convert(event.locationInWindow, from: nil)
            unfinishedStartVertex = targetVertex
            needsDisplay = true
            return
        }
        NSLog("Everything mouseDown \(ObjectIdentifier(self)) \(event.locationInWindow)")
        selectionStart = convert(event.locationInWindow, from: nil)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if unfinishedStart != nil {
            unfinishedStop = convert(event.locationInWindow, from: nil)
            drawUnfinishedEdge()
            needsDisplay = true
            return
        }
        if selectionStart != nil {
            NSLog("dragging selection box")
            selectionStop = convert(event.locationInWindow, from: nil)
            drawSelectionBox()
            needsDisplay = true
            return
        }
        
    }
    
    override func mouseUp(with event: NSEvent) {
        NSLog("Everything mouseUp   \(ObjectIdentifier(self)) \(event.locationInWindow)")
        let target = hitTest(convert(event.locationInWindow, from: nil))
        NSLog("hitTest: \(target)")
        if let targetVertex = target as? Vertex {
            makeEdge(to: targetVertex)
        }
        
        if selectionRect != nil {
            for rectangle in rectangles {
                if selectionRect!.contains(rectangle.center) {
                    rectangle.selected = true
                    selectedRectangles.append(rectangle)
                    rectangle.needsDisplay = true
                }
            }
            NSLog("selectedRectangles: \(selectedRectangles)")
        }
        
        unfinishedStart = nil
        unfinishedStop = nil
        unfinishedStartVertex = nil
        drawUnfinishedEdge()
        
        selectionStart = nil
        selectionStop = nil
        drawSelectionBox()
        needsDisplay = true

    }
    
    func makeEdge(to targetVertex: Vertex) {
        NSLog("Vertex makeEdge   \(ObjectIdentifier(self))")
        let start = unfinishedStartVertex
        if start != nil {
            var vertexPair : VertexPair
            if start!.center.x < targetVertex.center.x {
                vertexPair = VertexPair(start: targetVertex, finish: start!)
            } else {
                vertexPair = VertexPair(start: start!, finish: targetVertex)
            }
            vertexPairs.append(vertexPair)
            drawGuidePaths()
        }
    }

    override func viewDidMoveToSuperview() {
        for (i, name) in initialRectangles.enumerated() {
            let rectangleDesc = rectangleTypes[name]
            let rectangle = Rectangle(frame: CGRect(x:50 + 120*i, y:100, width: 80, height: 120))
            rectangle.descriptor = rectangleDesc
            rectangle.everything = self
            addSubview(rectangle)
            rectangles.append(rectangle)
        }
                
        self.wantsLayer = true
        
        curvesLayer.frame = self.frame
        curvesLayer.drawsAsynchronously = true
        curvesLayer.zPosition = 100
        layer!.addSublayer(curvesLayer)
        
        guidePathsLayer.frame = self.frame
        guidePathsLayer.drawsAsynchronously = true
        guidePathsLayer.zPosition = 99
        layer!.addSublayer(guidePathsLayer)
        
        
        drawGuidePaths()
        needsDisplay = true
    }
    

    
    func drawSelectionBox() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        
        NSLog("drawSelectionBox()")
        let selectionBox = CGMutablePath()
        if case let (start?, stop?) = (selectionStart, selectionStop) {
            NSLog("drawSelectionBox(): have start and stop")

            selectionRect = CGRect(x: min(start.x, stop.x), y: min(start.y, stop.y), width: abs(start.x - stop.x), height: abs(start.y - stop.y))
            selectionBox.addRect(selectionRect!)
        }
        
        if selectionShapeLayer == nil {
            selectionShapeLayer = CAShapeLayer()
        }
        selectionShapeLayer!.frame = self.frame
        selectionShapeLayer!.strokeColor = NSColor.blue.cgColor
        selectionShapeLayer!.fillColor = NSColor.blue.cgColor
        selectionShapeLayer!.opacity = 0.2
        selectionShapeLayer!.lineWidth = 1.0
        selectionShapeLayer!.path = selectionBox
        curvesLayer.addSublayer(selectionShapeLayer!)
        
        CATransaction.commit()
        
    }
    
    func drawUnfinishedEdge() {
        let context = NSGraphicsContext.current?.cgContext
        context?.setLineCap(.round)
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        
        unfinishedPath = CGMutablePath()
        if unfinishedStart != nil && unfinishedStop != nil {
            unfinishedPath!.move(to: unfinishedStart!)
            unfinishedPath!.addLine(to: unfinishedStop!)
            NSLog("have unfinished edge")
        }
        
        unfinishedEdgeShapeLayer!.frame = self.frame
        unfinishedEdgeShapeLayer!.strokeColor = NSColor.blue.cgColor
        unfinishedEdgeShapeLayer!.lineWidth = 1.0
        unfinishedEdgeShapeLayer!.path = unfinishedPath
        
        curvesLayer.addSublayer(unfinishedEdgeShapeLayer!)
        
        CATransaction.commit()
    }
    
    func plotLine(_ start: CGPoint, _ finish: CGPoint) -> CAShapeLayer {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: finish)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = self.frame
        shapeLayer.strokeColor = NSColor.black.cgColor
        shapeLayer.lineWidth = 1.0
        shapeLayer.path = path
        
        curvesLayer.addSublayer(shapeLayer)
        return shapeLayer
    }
    
    func drawGuidePaths() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        
        guidePathsLayer.sublayers = nil
        for vertexPair in vertexPairs {
            
            let startVertex = vertexPair.start
            let finishVertex = vertexPair.finish
            
            let guidePathStart = CGMutablePath()
            let guidePathFinish = CGMutablePath()

            let smallWidth = startVertex.frame.width
            let smallHeight = startVertex.frame.height
            
            let bigWidth = startVertex.frame.width * 6
            let bigHeight = startVertex.frame.height * 6
            
            let startX = startVertex.frame.minX - bigWidth/2 + smallWidth/2
            let finishX = finishVertex.frame.minX - bigWidth/2 + smallWidth/2
            
            var startY = CGFloat()
            var finishY = CGFloat()
            
            if startVertex.frame.minY > finishVertex.frame.minY {
                startY = startVertex.frame.minY + smallHeight/2 - bigHeight
                finishY = finishVertex.frame.minY + smallHeight/2
            } else {
                startY = startVertex.frame.minY + smallHeight/2
                finishY = finishVertex.frame.minY + smallHeight/2 - bigHeight
            }

            let startRect = NSRect(x: startX, y: startY, width: bigWidth, height: bigHeight)
            let finishRect = NSRect(x: finishX, y: finishY, width: bigWidth, height: bigHeight)
            
            let startCenter = startRect.center
            let finishCenter = finishRect.center
            
            func CGPointDistanceSquared(from: CGPoint, to: CGPoint) -> CGFloat {
                return (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
            }

            func CGPointDistance(from: CGPoint, to: CGPoint) -> CGFloat {
                return sqrt(CGPointDistanceSquared(from: from, to: to))
            }
            
            let radius = bigWidth/2
        
            /*
            let phi1 = 1.0 / sin(2*radius / CGPointDistance(from: startCenter, to: finishCenter))
            let phi2 = atan2(finishCenter.y - startCenter.y, finishCenter.x - startCenter.x)
            let phi3 = -1 * phi1 + phi2 - CGFloat.pi/2
            
            let xt1 = startCenter.x + radius * cos(phi3)
            let yt1 = startCenter.y + radius * sin(phi3)
            
            let xt2 = finishCenter.x + radius * cos(phi3 + CGFloat.pi)
            let yt2 = finishCenter.y + radius * sin(phi3 + CGFloat.pi)
 
 */
            
            let dist = CGPointDistance(from: startCenter, to: finishCenter)
            let alpha = acos(2 * radius / dist)
            var beta = acos((finishCenter.x - startCenter.x)/dist)
            let noFlipBeta = beta
            
            
            if startCenter.y >= finishCenter.y {
                beta *= -1.0
            }

            
            var offset: CGFloat
            if startVertex.frame.minY > finishVertex.frame.minY {
                offset = alpha - beta
            } else {
                offset = -1 * (beta + alpha)
            }
            
            let xt1 = startCenter.x + radius * cos(offset)
            let yt1 = startCenter.y - radius * sin(offset)
            
            let xt2 = finishCenter.x - radius * cos(offset)
            let yt2 = finishCenter.y + radius * sin(offset)
            

            
            func plotPoint(_ x: CGFloat, _ y: CGFloat) {
                NSLog("plotpoint: \(x), \(y)")
                let shapeLayer = CAShapeLayer()
                shapeLayer.frame = self.frame
                shapeLayer.strokeColor = NSColor.black.cgColor
                shapeLayer.lineWidth = 1.0
                let path = CGMutablePath()
                path.addEllipse(in: NSRect(x: x, y: y, width: 2, height: 2))
                shapeLayer.path = path
                guidePathsLayer.addSublayer(shapeLayer)
            }
            /*
            plotPoint(startX, startY)
            plotPoint(finishX, finishY)
            
            plotPoint(startCenter.x, startCenter.y)
            plotPoint(finishCenter.x, finishCenter.y)
            */
            let shapeLayer = plotLine(
                CGPoint(x: xt1, y: yt1),
                CGPoint(x: xt2, y: yt2)
            )
            guidePathsLayer.addSublayer(shapeLayer)
            
            

            var noFlipOffset: CGFloat
            if startVertex.frame.minY > finishVertex.frame.minY {
                noFlipOffset = alpha - beta
            } else {
                noFlipOffset = -1 * (beta + alpha)
            }
            
            if startCenter.y > finishCenter.y {
                noFlipOffset -= 4*CGFloat.pi/2
            }
            
            
            // guidePathStart.addEllipse(in: startRect.insetBy(dx: startRect.width*2, dy: startRect.height*2))
            if startVertex.frame.minY < finishVertex.frame.minY {
                guidePathStart.addArc(center: startCenter, radius: radius, startAngle:   3*CGFloat.pi/2, endAngle: abs(noFlipOffset), clockwise: true)
                guidePathFinish.addArc(center: finishCenter, radius: radius, startAngle:   CGFloat.pi/2, endAngle: abs(noFlipOffset) + CGFloat.pi, clockwise: true)
            } else {
                guidePathStart.addArc(center: startCenter, radius: radius, startAngle:     CGFloat.pi/2, endAngle: 0*CGFloat.pi/2 + abs(noFlipOffset), clockwise: false)
                guidePathFinish.addArc(center: finishCenter, radius: radius, startAngle: 3*CGFloat.pi/2, endAngle: 2*CGFloat.pi/2 + abs(noFlipOffset), clockwise: false)
            }


            func plot(path: CGMutablePath, color: CGColor) -> CAShapeLayer {
                let shapeLayer = CAShapeLayer()
                shapeLayer.frame = self.frame
                shapeLayer.strokeColor = color
                shapeLayer.fillColor = nil
                shapeLayer.lineWidth = 1.0
                shapeLayer.path = path
                return shapeLayer
            }
            
            
            let startCircle = CGMutablePath()
            startCircle.addEllipse(in: startRect)
            
            let finishCircle = CGMutablePath()
            finishCircle.addEllipse(in: finishRect)

            //guidePathsLayer.addSublayer(plot(path: startCircle, color: NSColor.lightGray.cgColor))
            //guidePathsLayer.addSublayer(plot(path: finishCircle, color: NSColor.lightGray.cgColor))

            guidePathsLayer.addSublayer(plot(path: guidePathStart, color: NSColor.black.cgColor))
            guidePathsLayer.addSublayer(plot(path: guidePathFinish, color: NSColor.black.cgColor))
        }
        CATransaction.commit()
    }
}

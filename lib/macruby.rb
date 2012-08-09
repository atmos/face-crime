framework 'Cocoa'
framework 'CoreGraphics'

class NSColor
  def toCGColor
    color_RGB = colorUsingColorSpaceName(NSCalibratedRGBColorSpace)
    ## approach #1
    # components = Array.new(4){Pointer.new(:double)}
    # color_RGB.getRed(components[0],
    #                 green: components[1],
    #                 blue: components[2],
    #                 alpha:components[3])
    # components.collect!{|x| x[0] }
    # approach #2
    components = [redComponent, greenComponent, blueComponent, alphaComponent]

    color_space = CGColorSpaceCreateWithName(KCGColorSpaceGenericRGB)
    color = CGColorCreate(color_space, components)
    CGColorSpaceRelease(color_space)
    color
  end
end

# NSVIew set background color & and set center
class NSView

  # set background like on IOS
  def background_color=(color)
    viewLayer = CALayer.layer
    viewLayer.backgroundColor = color.toCGColor
    self.wantsLayer = true # // view's backing store is using a Core Animation Layer
    self.layer = viewLayer
  end

  # helper to set nsview center like on IOS
  def center= (point)
    self.frameOrigin = [point.x-(self.frame.size.width/2), point.y-(self.frame.size.height/2)]
    self.needsDisplay = true
  end
end

# NSImage to CGImage
class NSImage
  def to_CGImage
    source = CGImageSourceCreateWithData(self.TIFFRepresentation, nil)
    maskRef = CGImageSourceCreateImageAtIndex(source, 0, nil)
  end
end

class FaceDetectionDelegate
  attr_accessor :window

  def initWithURL(url)
    case url
    when String
      @photo_url = NSURL.URLWithString(url)
    when NSURL
      @photo_url = url
    else
      raise "The FaceDetectionDelegate class was initiated with an unknown type object"
    end
    self
  end

  def applicationDidFinishLaunching(aNotification)
    window.delegate = self
    puts "Fetching and loading the image #{@photo_url.absoluteString}"
    image = NSImage.alloc.initWithContentsOfURL @photo_url

    @rohan    = NSImage.alloc.initWithContentsOfURL NSURL.URLWithString("https://raw.github.com/botriot/faceup/master/overlays/rohan.png")

    # Helpers to set the NSImageView size
    bitmap = NSBitmapImageRep.imageRepWithData image.TIFFRepresentation
    puts "image size: w=#{bitmap.pixelsWide}, h=#{bitmap.pixelsHigh}" if bitmap

    imageView = NSImageView.alloc.init
    imageView.image = image
    imageView.wantsLayer = true
    imageView.imageScaling = NSImageScaleProportionallyUpOrDown
    imageView.layer.affineTransform = CGAffineTransformMakeScale(-1, 1)
    imageView.imageFrameStyle = NSImageFramePhoto

    window.setFrame([0.0, 0.0, (bitmap.pixelsWide+20), (bitmap.pixelsHigh+20)], display:true, animate:true)
    window.center

    window.contentView.wantsLayer = true
    window.contentView.layer.affineTransform = CGAffineTransformMakeScale(1, 1)

    imageView.frame = CGRectMake(0.0, 0.0, bitmap.pixelsWide, bitmap.pixelsHigh)
    window.contentView.addSubview(imageView)
    detect_faces
    window.orderFrontRegardless

    # Works but missing stuff added in detect_faces
    image_rep = imageView.bitmapImageRepForCachingDisplayInRect(imageView.visibleRect)
    context = NSGraphicsContext.graphicsContextWithBitmapImageRep(image_rep)
    window.contentView.layer.renderInContext(context.graphicsPort)
    image_data = image_rep.representationUsingType(NSPNGFileType, properties:nil)

    # Writes a white image
    #window.contentView.lockFocus
    #image_rep = NSBitmapImageRep.alloc.initWithFocusedViewRect(window.contentView.frame)
    #window.contentView.unlockFocus
    #image_data = image_rep.representationUsingType(NSPNGFileType, properties:nil)

    image_data.writeToFile("rohan.png", atomically:true)
    exit(1)
  end

  def detect_faces
    ciImage = CIImage.imageWithCGImage window.contentView.subviews.last.image.to_CGImage
    detectorOptions = {CIDetectorAccuracy: CIDetectorAccuracyHigh }
    detector = CIDetector.detectorOfType "CIDetectorTypeFace", context:nil, options:detectorOptions
    features = detector.featuresInImage(ciImage)
    features.each do |feature|
      face = NSView.alloc.initWithFrame feature.bounds
      face.background_color = NSColor.yellowColor.colorWithAlphaComponent(0.4)
      #     window.contentView.addSubview(face)

      if(feature.hasLeftEyePosition)
        left_eye = NSView.alloc.initWithFrame CGRectMake(0, 0, 5, 5)
        left_eye.background_color = NSColor.blueColor.colorWithAlphaComponent(0.2)
        left_eye.center = feature.leftEyePosition
        #       window.contentView.addSubview(left_eye)
      end

      if(feature.hasRightEyePosition)
        right_eye = NSView.alloc.initWithFrame CGRectMake(0, 0, 5, 5)
        right_eye.background_color = NSColor.redColor.colorWithAlphaComponent(0.2)
        right_eye.center = feature.rightEyePosition
        #       window.contentView.addSubview(right_eye)
      end

      if(feature.hasMouthPosition)
        mouth = NSView.alloc.initWithFrame CGRectMake(0, 0, 10, 5)
        mouth.background_color = NSColor.greenColor.colorWithAlphaComponent(0.2)
        mouth.center = feature.mouthPosition
        #       window.contentView.addSubview(mouth)
      end

      if (feature.hasMouthPosition and feature.hasLeftEyePosition and feature.hasRightEyePosition)
        rohanView = NSImageView.alloc.init
        rohanView.image = @rohan
        rohanView.imageFrameStyle = NSImageFrameNone
        rohanView.imageScaling = NSScaleProportionally

        #w = feature.bounds.size.width
        #h = feature.bounds.size.height/2
        w = feature.bounds.size.width*5/4
        h = feature.bounds.size.height*5/4
        x = (feature.rightEyePosition.x + feature.leftEyePosition.x)/2 - w/2
        y = (feature.rightEyePosition.y + feature.leftEyePosition.y)/2 - h/2
        rohanView.frame = NSMakeRect(x, y, w, h)
        rohanView.frameCenterRotation = Math.atan2(feature.rightEyePosition.y-feature.leftEyePosition.y,feature.rightEyePosition.x-feature.leftEyePosition.x)*180/Math::PI

        window.contentView.addSubview(rohanView)
      end
    end
  end

  def windowWillClose(sender); exit(1); end
end

# Create the Application
application = NSApplication.sharedApplication
NSApplication.sharedApplication.activationPolicy = NSApplicationActivationPolicyRegular
application.delegate = FaceDetectionDelegate.alloc.initWithURL(ARGV.shift || "http://merbist.com/wp-content/uploads/2010/03/matz_koichi_matt_aimonetti_sansonetti_jimmy.jpg")

# create the Application Window
frame = [0.0, 0.0, 640, 480]
window = NSWindow.alloc.initWithContentRect frame,
  styleMask: NSTitledWindowMask | NSClosableWindowMask,
  backing: NSBackingStoreBuffered,
  defer: false

application.delegate.window = window
window.orderOut(nil)
window.display
puts "Starting the app..."
application.run

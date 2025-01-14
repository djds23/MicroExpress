// File: Express.swift - create this in Sources/MicroExpress

import Foundation
import NIO
import NIOHTTP1

enum BindableHost {
	case localhost
	case any
	case ipv4(String)
}

extension BindableHost {
	var host: String {
		switch self {
		case .localhost:
			return "localhost"
		case .any:
			// https://en.wikipedia.org/wiki/0.0.0.0
			return "0.0.0.0"
		case let .ipv4(ip):
			return ip
		}
	}
}

open class Express : Router {
  
  override public init() {}
  
  let loopGroup =
		MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
  
  open func listen(_ port: Int) {
    let reuseAddrOpt = ChannelOptions.socket(
      SocketOptionLevel(SOL_SOCKET),
      SO_REUSEADDR)
    let bootstrap = ServerBootstrap(group: loopGroup)
      .serverChannelOption(ChannelOptions.backlog, value: 256)
      .serverChannelOption(reuseAddrOpt, value: 1)
      .childChannelInitializer { channel in
				channel.pipeline.addHandler(HTTPServerPipelineHandler()).always {_ in
					channel.pipeline.addHandler(HTTPHandler(router: self))
        }
      }
      
      .childChannelOption(ChannelOptions.socket(
        IPPROTO_TCP, TCP_NODELAY), value: 1)
      .childChannelOption(reuseAddrOpt, value: 1)
      .childChannelOption(ChannelOptions.maxMessagesPerRead,
                          value: 1)
    
    do {
      let serverChannel =
        try bootstrap.bind(host: "localhost", port: port)
          .wait()
      print("Server running on:", serverChannel.localAddress!)
      
      try serverChannel.closeFuture.wait() // runs forever
    }
    catch {
      fatalError("failed to start server: \(error)")
    }
  }

  final class HTTPHandler : ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    
    let router : Router
    
    init(router: Router) {
      self.router = router
    }

    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
      let reqPart = self.unwrapInboundIn(data)
      
      switch reqPart {
        case .head(let header):
          let req = IncomingMessage(header: header)
          let res = ServerResponse(channel: ctx.channel)
          
          // trigger Router
          router.handle(request: req, response: res) {
            (items : Any...) in // the final handler
            res.status = .notFound
            res.send("No middleware handled the request!")
          }

        // ignore incoming content to keep it micro :-)
        case .body, .end: break
      }
    }
  }
}


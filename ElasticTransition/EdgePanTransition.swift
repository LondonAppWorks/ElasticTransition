/*

The MIT License (MIT)

Copyright (c) 2015 Luke Zhao <me@lkzhao.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

import UIKit

public class EdgePanTransition: NSObject, UIViewControllerAnimatedTransitioning, UIViewControllerInteractiveTransitioning, UIViewControllerTransitioningDelegate{
  @objc public var panThreshold:CGFloat = 0.2
  @objc public var edge:Edge = .right
  
  // private
  @objc var transitioning = false
  @objc var presenting = true
  @objc var interactive = false
  @objc weak var transitionContext:UIViewControllerContextTransitioning!
  @objc var container:UIView!
  @objc var size:CGSize{
    return container.bounds.size
  }
  @objc var frontView:UIView{
    return frontViewController.view
  }
  @objc var backView:UIView{
    return backViewController.view
  }
  @objc var frontViewController: UIViewController{
    return presenting ? toViewController : fromViewController
  }
  @objc var backViewController: UIViewController{
    return !presenting ? toViewController : fromViewController
  }
  @objc var toView:UIView{
    return toViewController.view
  }
  @objc var fromView:UIView{
    return fromViewController.view
  }
  @objc var toViewController:UIViewController{
    return transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
  }
  @objc var fromViewController:UIViewController{
    return transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
  }
  
  @objc var currentPanGR: UIPanGestureRecognizer?
  
  @objc var translation:CGPoint = CGPoint.zero
  @objc var dragPoint:CGPoint = CGPoint.zero
  
  @objc func update(){}
  
  @objc func setup(){
    transitioning = true

    backViewController.viewWillDisappear(true)
    
    container.insertSubview(backView, at: 0)
    container.addSubview(frontView)
  }

  @objc func clean(_ finished: Bool){
    // bug: http://openradar.appspot.com/radar?id=5320103646199808
    UIApplication.shared.keyWindow!.addSubview(finished ? toView : fromView)

    if(!presenting && finished || presenting && !finished){
      frontView.removeFromSuperview()
      backView.layer.transform = CATransform3DIdentity

      backViewController.viewDidAppear(true)
    }

    dragPoint = CGPoint.zero
    currentPanGR = nil
    interactive = false
    transitioning = false
    transitionContext.completeTransition(finished)
    transitionContext = nil
    container = nil
  }

  @objc var timeoutTimer:Timer?
  @objc func resetTimeout(){
    timeoutTimer?.invalidate()
    timeoutTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(timedOut), userInfo: nil, repeats: false)
  }
  @objc func timedOut(){
    if currentPanGR == nil || currentPanGR!.state != .changed {
      _ = endInteractiveTransition()
    }
  }
  @objc func startInteractivePresent(fromViewController fromVC:UIViewController, toViewController toVC:UIViewController?, identifier:String?, pan:UIPanGestureRecognizer, presenting:Bool, completion:(() -> Void)? = nil){
    if transitioning {
      return
    }
    resetTimeout()
    interactive = true
    currentPanGR = pan
    translation = pan.translation(in: pan.view!)
    dragPoint = pan.location(in: pan.view!)
    if presenting{
      if let identifier = identifier{
        fromVC.performSegue(withIdentifier: identifier, sender: self)
      }else if let toVC = toVC{
        fromVC.present(toVC, animated: true, completion: nil)
      }
    }else{
      fromVC.dismiss(animated: true, completion: completion)
    }
  }
  
  public func updateInteractiveTransition(gestureRecognizer pan:UIPanGestureRecognizer) -> Bool?{
    if !transitioning{
      return nil
    }
    if pan.state == .changed{
      translation = pan.translation(in: pan.view!)
      dragPoint = pan.location(in: pan.view!)
      update()
      resetTimeout()
      return nil
    }else{
      return endInteractiveTransition()
    }
  }
  
  @objc public func startInteractiveTransition(_ fromViewController:UIViewController, segueIdentifier identifier:String, gestureRecognizer pan:UIPanGestureRecognizer){
    self.startInteractivePresent(fromViewController:fromViewController, toViewController:nil, identifier:identifier, pan: pan, presenting: true)
  }
  
  @objc public func startInteractiveTransition(_ fromViewController:UIViewController, toViewController:UIViewController, gestureRecognizer pan:UIPanGestureRecognizer){
    self.startInteractivePresent(fromViewController:fromViewController, toViewController:toViewController, identifier:nil, pan: pan, presenting: true)
  }
  
  @objc public func dissmissInteractiveTransition(_ viewController:UIViewController, gestureRecognizer pan:UIPanGestureRecognizer, completion:(() -> Void)?){
    self.startInteractivePresent(fromViewController:viewController, toViewController:nil, identifier:nil, pan: pan, presenting: false, completion: completion)
  }
  
  
  public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    if transitioning {
        return
    }
    self.transitionContext = transitionContext
    self.container = transitionContext.containerView
    setup()
  }
  
  public func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning){
    animateTransition(using: transitionContext)
  }
  
  @objc func cancelInteractiveTransition(){
    self.transitionContext.cancelInteractiveTransition()
  }
  
  @objc func finishInteractiveTransition(){
    self.transitionContext.finishInteractiveTransition()
  }
  
  @objc func endInteractiveTransition() -> Bool{
    timeoutTimer?.invalidate()
    let finished:Bool
    if let pan = currentPanGR{
      let translation = pan.translation(in: pan.view!)
      var progress:CGFloat
      switch edge{
      case .left:
        progress =  translation.x / pan.view!.frame.width
      case .right:
        progress =  translation.x / pan.view!.frame.width * -1
      case .bottom:
        progress =  translation.y / pan.view!.frame.height * -1
      case .top:
        progress =  translation.y / pan.view!.frame.height
      }
      progress = presenting ? progress : -progress
      if(progress > panThreshold){
        finished = true
      } else {
        finished = false
      }
    }else{
      finished = true
    }
    if finished{
      finishInteractiveTransition()
    }else{
      cancelInteractiveTransition()
    }
    return finished
  }
  
  
  public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return 0.5
  }
  
  public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    if transitioning{
        return nil
    }
    self.presenting = true
    return self
  }
  
  public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    if transitioning{
      return nil
    }
    self.presenting = false
    return self
  }
  
  public func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    if transitioning{
      return nil
    }
    self.presenting = true
    return self.interactive ? self : nil
  }
  
  public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    if transitioning{
      return nil
    }
    self.presenting = false
    return self.interactive ? self : nil
  }

  @objc var presentationController:ElasticTransitionPresentationController!
  public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
    presentationController = ElasticTransitionPresentationController(presentedViewController: presented, presenting: presenting)
    presentationController.transition = self as? ElasticTransition
    return presentationController
  }
}

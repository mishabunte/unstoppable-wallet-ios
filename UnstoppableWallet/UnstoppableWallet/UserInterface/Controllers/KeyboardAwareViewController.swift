import RxCocoa
import RxSwift

import UIExtensions
import UIKit

class KeyboardAwareViewController: ThemeViewController {
    private let scrollViews: [UIScrollView]

    private var translucentContentOffset: CGFloat = 0
    private var keyboardFrame: CGRect?

    // handling accessory view position
    var additionalContentInsets: UIEdgeInsets = .zero { // additional inset. Put scrollView content under accessoryView, usign .bottom = newValue
        didSet {
            updateInsets()
        }
    }

    var additionalInsetsOnlyForClosedKeyboard: Bool = true // AdditionalContentInsets by default using only in closed state (mean that not for accessoryView, but wrapper on screen bottom)

    var oldPadding: CGFloat = 0

    var accessoryView: UIView?

    var ignoreSafeAreaForAccessoryView = true // when accessory view is wrapper which covering safeArea. You must setInitialState(bottomPadding: wrapper.height) in didAppear(:)

    private var pseudoAccessoryView: PseudoAccessoryView?

    public var shouldObserveKeyboard = true
    var pendingFrame: CGRect?

    private let keyboardVisibilityRelay = BehaviorRelay<CGFloat>(value: 0)
    var showAccessoryView: Bool = true

    open var accessoryViewHeight: CGFloat {
        showAccessoryView ? floor(accessoryView?.height ?? 0) : 0 // need to use height without safe-area because tableview already use safe-area insets
    }

    override open var inputAccessoryView: UIView? {
        pseudoAccessoryView
    }

    override open var canBecomeFirstResponder: Bool {
        accessoryView != nil ? shouldObserveKeyboard : super.canBecomeFirstResponder
    }

    init(scrollViews: [UIScrollView], accessoryView: UIView? = nil) {
        self.scrollViews = scrollViews
        self.accessoryView = accessoryView

        super.init()

        if accessoryView != nil {
            let pseudoAccessoryView = PseudoAccessoryView()
            pseudoAccessoryView.backgroundColor = UIColor.clear
            pseudoAccessoryView.isUserInteractionEnabled = false

            pseudoAccessoryView.delegate = self

            self.pseudoAccessoryView = pseudoAccessoryView
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func loadView() {
        super.loadView()

        view.becomeFirstResponder()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        pseudoAccessoryView?.heightValue = accessoryViewHeight

        for scrollView in scrollViews {
            scrollView.alwaysBounceVertical = true
            scrollView.showsVerticalScrollIndicator = false
            scrollView.keyboardDismissMode = .interactive
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        observeKeyboard(true)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    private func observeKeyboard(_ start: Bool) {
        if start {
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

            shouldObserveKeyboard = true
        } else {
            NotificationCenter.default.removeObserver(self)

            shouldObserveKeyboard = false
        }
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let frame = pendingFrame {
            layoutAccessoryView(keyboardFrame: frame)
        }
        pendingFrame = nil

        translucentContentOffset = scrollViews[0].contentOffset.y

        if let accessoryView {
            setInitialState(bottomPadding: accessoryView.height)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        observeKeyboard(false)
    }

    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if let frame = pendingFrame {
            layoutAccessoryView(keyboardFrame: frame)
        }
        pendingFrame = nil
    }

    @objc private func keyboardWillShow(notification: Notification) {
        guard let oldKeyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue,
              let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              oldKeyboardFrame != keyboardFrame
        else {
            return
        }
        // check in visible only accessoryView. If true - keyboard is hidden
        if let inputAccessoryViewHeight = accessoryView?.height, inputAccessoryViewHeight.isZero || keyboardFrame.height.isZero || keyboardFrame.height == inputAccessoryViewHeight {
            keyboardWillHide(notification: notification)
            return
        }
        // try to disable dismiss controller by swipe when keyboard is visible
        navigationController?.presentationController?.presentedView?.gestureRecognizers?.first?.isEnabled = false
        self.keyboardFrame = keyboardFrame
        pseudoAccessoryView?.heightValue = accessoryViewHeight

        let insets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardFrame.height - view.safeAreaInsets.bottom, right: 0).add(additionalInsetsOnlyForClosedKeyboard ? .zero : additionalContentInsets)
        for scrollView in scrollViews {
            scrollView.contentInset = insets
            scrollView.scrollIndicatorInsets = insets
        }
    }

    @objc private func keyboardWillHide(notification _: Notification) {
        // try to enable dismiss controller by swipe when keyboard is hidden
        navigationController?.presentationController?.presentedView?.gestureRecognizers?.first?.isEnabled = true
        keyboardFrame = nil
        pseudoAccessoryView?.heightValue = accessoryViewHeight

        updateInsets()
    }

    public func setInitialState(bottomPadding: CGFloat) {
        pseudoAccessoryView?.heightValue = bottomPadding
        oldPadding = -bottomPadding
    }

    public func updateInsets() {
        var bottomInset: CGFloat = 0
        if showAccessoryView {
            bottomInset = accessoryViewHeight
        }
        if !ignoreSafeAreaForAccessoryView {
            bottomInset -= view.safeAreaInsets.bottom
        }

        for scrollView in scrollViews {
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0).add(additionalContentInsets)
            scrollView.scrollIndicatorInsets = .zero
        }
    }

    public func updateUIKeyboard(initial _: Bool = false) {
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()

            self.pseudoAccessoryView?.heightValue = self.accessoryViewHeight
        }
    }

    private func layoutAccessoryView(keyboardFrame: CGRect) {
        let inputHeight = pseudoAccessoryView?.heightValue ?? 0
        var bottomPadding = -inputHeight
        if !keyboardFrame.equalTo(CGRect.zero) {
            bottomPadding += view.frame.size.height - keyboardFrame.origin.y
        }

        let maxPadding = keyboardFrame.size.height - inputHeight
        bottomPadding = min(max(0, bottomPadding), keyboardFrame.size.height - inputHeight)

        let visiblePercent = maxPadding == 0 ? 0 : bottomPadding / maxPadding
        keyboardVisibilityRelay.accept(visiblePercent)

        accessoryView?.snp.updateConstraints { make in
            make.bottom.equalToSuperview().offset(-bottomPadding)
        }

        oldPadding = bottomPadding

        view.layoutIfNeeded()
    }

    override open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        let stopObserveKeyboard = !viewControllerToPresent.isKind(of: UISearchController.self) // SearchControllers presenting transparent on parent and need to obsevre parent content
        if stopObserveKeyboard {
            view.endEditing(true)
        }

        if let programmaticallyDismissedViewController = viewControllerToPresent as? IDeinitDelegate {
            programmaticallyDismissedViewController.onDeinit = { [weak self] in
                self?.observeKeyboard(true)
            }
        }
        viewControllerToPresent.presentationController?.delegate = self

        let awaitClosingKeyboardTime: TimeInterval = keyboardFrame == nil ? 0 : 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + awaitClosingKeyboardTime) { // Time delay needed to handle keyboard dismissing (change insets and accessory position)
            super.present(viewControllerToPresent, animated: flag) { [weak self] in
                if stopObserveKeyboard {
                    self?.observeKeyboard(false)
                }
                completion?()
            }
        }
    }

    func syncContentOffsetIfRequired(textView: UITextView) {
        guard let keyboardFrame else {
            return
        }

        var shift: CGFloat = 0

        if let cursorPosition = textView.selectedTextRange?.start {
            let caretPositionFrame: CGRect = textView.convert(textView.caretRect(for: cursorPosition), to: nil)
            let caretVisiblePosition = caretPositionFrame.origin.y - .margin2x + translucentContentOffset

            if caretVisiblePosition < 0 {
                shift = caretVisiblePosition + scrollViews[0].contentOffset.y
            } else {
                shift = max(0, caretPositionFrame.origin.y + caretPositionFrame.height + .margin2x - keyboardFrame.origin.y) + scrollViews[0].contentOffset.y
            }
        }

        scrollViews[0].setContentOffset(CGPoint(x: 0, y: shift), animated: true)
    }
}

extension KeyboardAwareViewController {
    public var keyboardVisibilityDriver: Driver<CGFloat> {
        keyboardVisibilityRelay.asDriver()
    }
}

extension KeyboardAwareViewController: PseudoAccessoryViewDelegate {
    func pseudoAccessoryView(_: PseudoAccessoryView, keyboardFrameDidChange frame: CGRect) {
        let keyboardFrame = view.convert(frame, from: nil)

        if shouldObserveKeyboard {
            layoutAccessoryView(keyboardFrame: keyboardFrame)
        } else {
            pendingFrame = keyboardFrame
        }
    }
}

extension KeyboardAwareViewController: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerWillDismiss(_: UIPresentationController) {
//        print("presentationControllerWillDismiss : \(presentationController)")
    }

    public func presentationControllerDidDismiss(_: UIPresentationController) {
        observeKeyboard(true)
//        print("presentationControllerDidDismiss : \(presentationController)")
    }

    public func presentationControllerDidAttemptToDismiss(_: UIPresentationController) {
//        print("presentationControllerDidDismiss : \(presentationController)")
    }
}

extension KeyboardAwareViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.view is UITableView
    }
}

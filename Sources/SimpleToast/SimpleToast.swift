//
//  SimpleToast.swift
//
//  This file is part of the SimpleToast Swift library: https://github.com/sanzaru/SimpleToast
//  Created by Martin Albrecht on 12.07.20.
//  Licensed under Apache License v2.0
//

import SwiftUI
import Combine

struct SimpleToast<SimpleToastContent: View, Item>: ViewModifier {
    @State private var offset: CGSize = .zero
    @State private var isInit = false
    @State private var viewState = false
    @State private var cancelable: Cancellable?
    
    @Binding private var toastItem: Item?
    
    private let options: SimpleToastOptions
    private let onDismiss: (() -> Void)?
    private let toastInnerContent: (Item) -> SimpleToastContent
    
    private var showToast: Bool { toastItem != nil }
    
    init(
        toastItem: Binding<Item?>,
        options: SimpleToastOptions,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> SimpleToastContent
    ) {
        self._toastItem = toastItem
        self.options = options
        self.onDismiss = onDismiss
        self.toastInnerContent = content
    }
    
    @ViewBuilder
    private var toastContent: some View {
        if let item = toastItem {
            let content = toastInnerContent(item)
            
            let showToastBinding = Binding<Bool> {
                toastItem != nil
            } set: { _ in
                toastItem = nil
            }
            
            Group {
                switch options.modifierType {
                case .slide:
                    content
                        .modifier(SimpleToastSlide(showToast: showToastBinding, options: options))
                        .modifier(SimpleToastDragGestureModifier(offset: $offset, options: options, onCompletion: dismiss))

                case .scale:
                    content
                        .modifier(SimpleToastScale(showToast: showToastBinding, options: options))
                        .modifier(SimpleToastDragGestureModifier(offset: $offset, options: options, onCompletion: dismiss))

                case .skew:
                    content
                        .modifier(SimpleToastSkew(showToast: showToastBinding, options: options))

                case .fade:
                    content
                        .modifier(SimpleToastFade(showToast: showToastBinding, options: options))
                        .modifier(SimpleToastDragGestureModifier(offset: $offset, options: options, onCompletion: dismiss))
                }
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay( // Backdrop
                Group {
                    EmptyView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(options.backdrop?.edgesIgnoringSafeArea(.all))
                .opacity(options.backdrop != nil && showToast ? 1 : 0)
                .onTapGesture(perform: dismiss)
            )
            .overlay( // Toast Content
                toastContent,
                alignment: options.alignment
            )
    }
    
    /// Initialize the dismiss timer and set init variable
    private func setup() {
        dismissAfterTimeout()
        isInit = true
    }

    /// Update the dismiss timer if state has changed.
    ///
    /// This function is required, because the onAppear will not be triggered again until a full dismissal of the view
    /// happened. Retriggering the toast resulted in unset timers and thus never disappearing toasts.
    ///
    /// See [the GitHub issue](https://github.com/sanzaru/SimpleToast/issues/24) for more information.
    private func update(state: Bool) {
        // We need to keep track of the current view state and only update on changing values. The onReceive modifier
        // will otherwise constantly trigger updates when the toast is initialized with an Identifiable instead of Bool
        if state != viewState {
            viewState = state

            if isInit, viewState {
                dismissAfterTimeout()
            }
        }
    }

    /// Dismiss the sheet after the timeout specified in the options
    private func dismissAfterTimeout() {
        if let timeout = options.hideAfter, showToast, options.hideAfter != nil {
            cancelable = Timer.publish(every: timeout, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    cancelable?.cancel()
                    dismiss()
                }
        }
    }

    /// Dismiss the toast and reset all nessasary parameters
    private func dismiss() {
        withAnimation(options.animation) {
            cancelable?.cancel()
            toastItem = nil
            viewState = false
            offset = .zero

            onDismiss?()
        }
    }
    /// Dismiss the toast Base on dismissOnTap
    private func dismissOnTap() {
        if options.dismissOnTap ?? true {
            self.dismiss()
        }
    }
}

// MARK: - View extensions

public extension View {
    /// Present the sheet based on the state of a given binding to a boolean.
    ///
    /// - NOTE: The toast will be attached to the view's frame it is attached to and not the general UIScreen.
    /// - Parameters:
    ///   - isPresented: Boolean binding as source of truth for presenting the toast
    ///   - options: Options for the toast
    ///   - onDismiss: Closure called when the toast is dismissed
    ///   - content: Inner content for the toast
    /// - Returns: The toast view
    func simpleToast<SimpleToastContent: View>(
        isPresented: Binding<Bool>,
        options: SimpleToastOptions,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SimpleToastContent
    ) -> some View {
        let binding = Binding<Bool?> {
            isPresented.wrappedValue ? true : nil
        } set: {
            isPresented.wrappedValue = $0 ?? false
        }
        
        return self.modifier(
            SimpleToast<SimpleToastContent, Bool>(toastItem: binding, options: options, onDismiss: onDismiss, content: { _ in content() })
        )
    }

    /// Present the sheet based on the state of a given optional item.
    /// If the item is non-nil the toast will be shown, otherwise it is dimissed.
    ///
    /// - NOTE: The toast will be attached to the view's frame it is attached to and not the general UIScreen.
    /// - Parameters:
    ///   - item: Optional item as source of truth for presenting the toast
    ///   - options: Options for the toast
    ///   - onDismiss: Closure called when the toast is dismissed
    ///   - content: Inner content for the toast
    /// - Returns: The toast view
    func simpleToast<SimpleToastContent: View, Item>(
        item: Binding<Item?>,
        options: SimpleToastOptions,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> SimpleToastContent
    ) -> some View {
        self.modifier(
            SimpleToast(toastItem: item, options: options, onDismiss: onDismiss, content: content)
        )
    }
}

// MARK: - Deprecated
public extension View {
    /// Present the sheet based on the state of a given binding to a boolean.
    ///
    /// - NOTE: The toast will be attached to the view's frame it is attached to and not the general UIScreen.
    /// - Parameters:
    ///   - isShowing: Boolean binding as source of truth for presenting the toast
    ///   - options: Options for the toast
    ///   - onDismiss: Closure called when the toast is dismissed
    ///   - content: Inner content for the toast
    /// - Returns: The toast view
    @available(*, deprecated, renamed: "simpleToast(isPresented:options:onDismiss:content:)")
    func simpleToast<SimpleToastContent: View>(
        isShowing: Binding<Bool>,
        options: SimpleToastOptions,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SimpleToastContent
    ) -> some View {
        self.simpleToast(isPresented: isShowing, options: options, onDismiss: onDismiss, content: content)
    }
}

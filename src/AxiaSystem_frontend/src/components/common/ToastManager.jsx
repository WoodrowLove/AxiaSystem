import React, { useState, useCallback, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Animated,
  Easing,
  TouchableOpacity,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import theme from '../styles/theme';
import shadows from '../styles/shadows';
import Typography from './Typography';

/**
 * ToastManager Component
 *
 * Manages multiple toasts and handles their display and dismissal.
 *
 * @returns {JSX.Element}
 */
const ToastManager = () => {
  const [toasts, setToasts] = useState([]);

  const addToast = useCallback((message, type = 'info', duration = 3000) => {
    const id = Date.now().toString();
    const toast = { id, message, type, duration };
    setToasts((prev) => [...prev, toast]);

    // Auto-remove toast after duration
    setTimeout(() => removeToast(id), duration);
  }, []);

  const removeToast = useCallback((id) => {
    setToasts((prev) => prev.filter((toast) => toast.id !== id));
  }, []);

  return (
    <View style={styles.container}>
      {toasts.map((toast) => (
        <Toast
          key={toast.id}
          message={toast.message}
          type={toast.type}
          onDismiss={() => removeToast(toast.id)}
        />
      ))}
    </View>
  );
};

/**
 * Toast Component
 *
 * @param {Object} props - Props for the Toast component.
 * @param {string} props.message - The message to display.
 * @param {string} [props.type='info'] - Type of toast: 'success', 'error', 'info'.
 * @param {number} [props.duration=3000] - Duration in milliseconds before auto-dismiss.
 * @param {Function} [props.onDismiss] - Callback function when the toast is dismissed.
 * @returns {JSX.Element}
 */
const Toast = ({ message, type = 'info', onDismiss }) => {
  const [fadeAnim] = useState(new Animated.Value(0)); // Animation value

  useEffect(() => {
    // Fade in animation
    Animated.timing(fadeAnim, {
      toValue: 1,
      duration: 300,
      easing: Easing.out(Easing.ease),
      useNativeDriver: true,
    }).start();

    return () => {
      fadeOut(); // Ensure cleanup
    };
  }, []);

  const fadeOut = () => {
    Animated.timing(fadeAnim, {
      toValue: 0,
      duration: 300,
      easing: Easing.in(Easing.ease),
      useNativeDriver: true,
    }).start(() => {
      if (onDismiss) onDismiss(); // Trigger dismiss callback
    });
  };

  return (
    <Animated.View
      style={[
        styles.toast,
        shadows.medium,
        styles[type],
        { opacity: fadeAnim },
      ]}
    >
      <LinearGradient
        colors={theme.toasts[type].gradientColors || [theme.colors[type], theme.colors[type]]}
        style={StyleSheet.absoluteFill}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 0 }}
      />
      <Typography variant="body" color={theme.colors.white}>
        {message}
      </Typography>
      <TouchableOpacity onPress={fadeOut} style={styles.dismiss}>
        <Text style={styles.dismissText}>×</Text>
      </TouchableOpacity>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 20,
    left: 0,
    right: 0,
    zIndex: 9999,
    alignItems: 'center',
  },
  toast: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 12,
    marginVertical: 6,
    marginHorizontal: 16,
    borderRadius: theme.sizes.borderRadius,
    zIndex: 1000,
    overflow: 'hidden',
  },
  dismiss: {
    marginLeft: 10,
    padding: 4,
  },
  dismissText: {
    color: theme.colors.white,
    fontSize: 16,
    fontWeight: 'bold',
  },
  success: {
    backgroundColor: theme.colors.success,
  },
  error: {
    backgroundColor: theme.colors.error,
  },
  info: {
    backgroundColor: theme.colors.info,
  },
});

export { ToastManager, Toast };
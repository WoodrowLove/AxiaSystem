import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Animated,
  Easing,
  TouchableOpacity,
} from 'react-native';
import theme from '../styles/theme';
import shadows from '../styles/shadows';
import Typography from './Typography';

/**
 * Toast Component
 *
 * @param {Object} props - Props for the Toast component.
 * @param {string} props.message - The message to display.
 * @param {string} [props.type='info'] - Type of toast: 'success', 'error', 'info'.
 * @param {number} [props.duration=3000] - Duration in milliseconds before auto-dismiss.
 * @param {Function} [props.onDismiss] - Callback function when the toast is dismissed.
 */
const Toast = ({ message, type = 'info', duration = 3000, onDismiss }) => {
  const [fadeAnim] = useState(new Animated.Value(0)); // Animation value

  useEffect(() => {
    // Fade in animation
    Animated.timing(fadeAnim, {
      toValue: 1,
      duration: 300,
      easing: Easing.out(Easing.ease),
      useNativeDriver: true,
    }).start();

    // Auto-dismiss after the specified duration
    const timer = setTimeout(() => {
      fadeOut();
    }, duration);

    return () => clearTimeout(timer);
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
  toast: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 12,
    marginVertical: 6,
    marginHorizontal: 16,
    borderRadius: theme.sizes.borderRadius,
    position: 'absolute',
    bottom: 50,
    left: 0,
    right: 0,
    zIndex: 1000,
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

export default Toast;
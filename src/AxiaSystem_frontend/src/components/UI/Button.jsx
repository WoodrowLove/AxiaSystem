import React from 'react';
import { TouchableOpacity, StyleSheet, View, ActivityIndicator, Animated } from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import Typography from './Typography';
import shadows from '../styles/shadows';
import theme from '../styles/theme';

const Button = ({
  title, // Button text
  onPress, // Function to handle button press
  variant = 'primary', // Button variant: 'primary', 'secondary', 'text', 'danger'
  gradient = true, // Enable gradient background
  disabled = false, // Disable button
  loading = false, // Show loading spinner
  style, // Additional styles for the button
  textStyle, // Additional styles for the text
  colors, // Override default gradient colors
  icon, // Optional: Pass an icon component
  iconPosition = 'left', // Icon position: 'left', 'right'
  animation = true, // Enable animation
}) => {
  const animatedValue = new Animated.Value(1); // Scale for press animation

  // Define button background based on variant
  const gradientColors = colors || theme.buttons[variant]?.gradientColors || theme.colors.primaryGradient;
  const buttonStyle = [
    styles.buttonBase,
    theme.buttons[variant]?.style || styles.defaultStyle,
    shadows[variant === 'text' ? 'none' : 'medium'], // Add shadow for non-text buttons
    disabled && styles.disabled, // Apply disabled styles
    style, // Additional custom styles
  ];

  // Button press animation
  const handlePressIn = () => {
    if (animation) {
      Animated.timing(animatedValue, {
        toValue: 0.95,
        duration: 100,
        useNativeDriver: true,
      }).start();
    }
  };

  const handlePressOut = () => {
    if (animation) {
      Animated.timing(animatedValue, {
        toValue: 1,
        duration: 100,
        useNativeDriver: true,
      }).start();
    }
  };

  return (
    <Animated.View style={{ transform: [{ scale: animatedValue }] }}>
      <TouchableOpacity
        onPress={onPress}
        disabled={disabled || loading} // Disable button when loading or explicitly disabled
        style={buttonStyle}
        activeOpacity={0.8} // Slightly reduce opacity on press
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
      >
        {gradient && variant !== 'text' ? (
          <LinearGradient
            colors={gradientColors}
            style={StyleSheet.absoluteFill} // Full size gradient
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 0 }}
          />
        ) : null}
        <View style={styles.content}>
          {icon && iconPosition === 'left' && <View style={styles.icon}>{icon}</View>}
          {loading ? (
            <ActivityIndicator size="small" color={theme.colors.white} />
          ) : (
            <Typography
              variant={theme.buttons[variant]?.textVariant || 'bodyBold'}
              color={theme.buttons[variant]?.textColor || theme.colors.white}
              style={textStyle}
            >
              {title}
            </Typography>
          )}
          {icon && iconPosition === 'right' && <View style={styles.icon}>{icon}</View>}
        </View>
      </TouchableOpacity>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  buttonBase: {
    borderRadius: theme.sizes.buttonRadius,
    paddingVertical: theme.sizes.buttonPaddingVertical,
    paddingHorizontal: theme.sizes.buttonPaddingHorizontal,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden', // Clip gradient to button bounds
  },
  defaultStyle: {
    backgroundColor: theme.colors.primary,
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  icon: {
    marginHorizontal: 8, // Space between icon and text
  },
  disabled: {
    opacity: 0.5, // Make disabled buttons visually distinct
  },
});

export default Button;

import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import theme from '../styles/theme';

/**
 * Badge Component
 *
 * @param {Object} props - Props for the Badge component.
 * @param {string|number} props.content - The content to display inside the badge.
 * @param {string} props.variant - The variant of the badge: 'success', 'error', 'warning', 'info'.
 * @param {Object} props.style - Additional styles for the badge container.
 * @param {Object} props.textStyle - Additional styles for the badge text.
 * @param {number} props.size - Size of the badge (default: 24).
 * @param {boolean} props.absolute - Whether the badge is positioned absolutely.
 * @param {Object} props.position - Custom position for the badge when absolute (e.g., { top: -10, right: -10 }).
 * @returns {JSX.Element}
 */
const Badge = ({
  content,
  variant = 'info', // Default variant
  style = {},
  textStyle = {},
  size = 24,
  absolute = false,
  position = { top: -5, right: -5 },
}) => {
  const badgeStyle = [
    styles.badge,
    styles[variant], // Apply variant styles
    { width: size, height: size, borderRadius: size / 2 },
    absolute && { position: 'absolute', ...position },
    style,
  ];

  const textStyles = [
    styles.text,
    { fontSize: size * 0.5 },
    textStyle,
  ];

  return (
    <View style={badgeStyle}>
      {content != null && (
        <Text style={textStyles}>{content}</Text>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  badge: {
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: theme.colors.info,
  },
  text: {
    color: theme.colors.white,
    fontWeight: 'bold',
  },
  success: {
    backgroundColor: theme.colors.success,
  },
  error: {
    backgroundColor: theme.colors.error,
  },
  warning: {
    backgroundColor: theme.colors.warning,
  },
  info: {
    backgroundColor: theme.colors.info,
  },
});

export default Badge;
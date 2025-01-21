// Typography.js
import React from 'react';
import { Text, StyleSheet } from 'react-native';
import theme from '../styles/theme';

const Typography = ({ 
  variant = 'body', // Default typography variant
  color = 'textPrimary', // Default color
  style, // Additional styles
  children, // Text content
  ...props // Other Text props
}) => {
  const textStyle = [
    styles[variant],
    { color: theme.colors[color] || color }, // Supports custom hex or theme color
    style, // Allow overriding styles
  ];

  return (
    <Text style={textStyle} {...props}>
      {children}
    </Text>
  );
};

// Define styles using the typography section from theme.js
const styles = StyleSheet.create({
  heading: {
    fontFamily: theme.typography.fontFamily,
    fontSize: theme.typography.heading.fontSize,
    fontWeight: theme.typography.heading.fontWeight,
    lineHeight: theme.typography.heading.lineHeight,
  },
  subheading: {
    fontFamily: theme.typography.fontFamily,
    fontSize: theme.typography.subheading.fontSize,
    fontWeight: theme.typography.subheading.fontWeight,
    lineHeight: theme.typography.subheading.lineHeight,
  },
  body: {
    fontFamily: theme.typography.fontFamily,
    fontSize: theme.typography.body.fontSize,
    fontWeight: theme.typography.body.fontWeight,
    lineHeight: theme.typography.body.lineHeight,
  },
  small: {
    fontFamily: theme.typography.fontFamily,
    fontSize: theme.typography.small.fontSize,
    fontWeight: theme.typography.small.fontWeight,
    lineHeight: theme.typography.small.lineHeight,
  },
  tiny: {
    fontFamily: theme.typography.fontFamily,
    fontSize: theme.typography.tiny.fontSize,
    fontWeight: theme.typography.tiny.fontWeight,
    lineHeight: theme.typography.tiny.lineHeight,
  },
});

export default Typography;
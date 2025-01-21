import React from 'react';
import { View, StyleSheet, Text } from 'react-native';
import { Circle } from 'react-native-svg';
import Svg from 'react-native-svg';
import theme from '../styles/theme';

/**
 * Circular Progress Bar Component
 *
 * @param {Object} props - Props for the progress bar.
 * @param {number} props.progress - Current progress as a percentage (0-100).
 * @param {number} props.size - Diameter of the circular progress bar.
 * @param {number} props.strokeWidth - Width of the progress stroke.
 * @param {string} props.color - Color of the progress stroke.
 * @param {string} props.backgroundColor - Background stroke color.
 * @returns {JSX.Element}
 */
const CircularProgressBar = ({
  progress = 0,
  size = 100,
  strokeWidth = 10,
  color = theme.colors.primary,
  backgroundColor = theme.colors.border,
}) => {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - (progress / 100) * circumference;

  return (
    <View style={styles.container}>
      <Svg height={size} width={size}>
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={backgroundColor}
          strokeWidth={strokeWidth}
          fill="none"
        />
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={color}
          strokeWidth={strokeWidth}
          strokeDasharray={`${circumference} ${circumference}`}
          strokeDashoffset={strokeDashoffset}
          fill="none"
        />
      </Svg>
      <View style={StyleSheet.absoluteFill}>
        <Text style={styles.label}>{Math.round(progress)}%</Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  label: {
    fontSize: theme.fontSizes.md,
    color: theme.colors.text,
    textAlign: 'center',
  },
});

export default CircularProgressBar;
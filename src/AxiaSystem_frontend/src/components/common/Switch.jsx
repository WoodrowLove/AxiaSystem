import React from 'react';
import { TouchableWithoutFeedback, Animated, View, StyleSheet } from 'react-native';
import theme from '../styles/theme';

/**
 * Switch/Toggle Component
 *
 * @param {Object} props - Props for the Switch component.
 * @param {boolean} props.value - Current value of the switch (true/false).
 * @param {Function} props.onValueChange - Callback function when the switch is toggled.
 * @param {string} props.variant - Style variant for the switch: 'primary', 'secondary', 'custom'.
 * @param {Object} props.style - Additional styles for the switch container.
 * @param {Object} props.trackStyle - Additional styles for the track.
 * @param {Object} props.thumbStyle - Additional styles for the thumb.
 * @returns {JSX.Element}
 */
const Switch = ({
  value = false,
  onValueChange = () => {},
  variant = 'primary',
  style = {},
  trackStyle = {},
  thumbStyle = {},
}) => {
  const animatedValue = React.useRef(new Animated.Value(value ? 1 : 0)).current;

  React.useEffect(() => {
    Animated.timing(animatedValue, {
      toValue: value ? 1 : 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [value]);

  const trackBackgroundColor = animatedValue.interpolate({
    inputRange: [0, 1],
    outputRange: [
      theme.switch[variant].trackOff,
      theme.switch[variant].trackOn,
    ],
  });

  const thumbPosition = animatedValue.interpolate({
    inputRange: [0, 1],
    outputRange: [2, theme.sizes.switchWidth - theme.sizes.thumbSize - 2],
  });

  return (
    <TouchableWithoutFeedback onPress={() => onValueChange(!value)}>
      <View style={[styles.container, style]}>
        <Animated.View
          style={[
            styles.track,
            { backgroundColor: trackBackgroundColor },
            trackStyle,
          ]}
        />
        <Animated.View
          style={[
            styles.thumb,
            { left: thumbPosition },
            thumbStyle,
          ]}
        />
      </View>
    </TouchableWithoutFeedback>
  );
};

const styles = StyleSheet.create({
  container: {
    width: theme.sizes.switchWidth,
    height: theme.sizes.switchHeight,
    borderRadius: theme.sizes.switchHeight / 2,
    justifyContent: 'center',
  },
  track: {
    width: '100%',
    height: '100%',
    borderRadius: theme.sizes.switchHeight / 2,
    position: 'absolute',
  },
  thumb: {
    width: theme.sizes.thumbSize,
    height: theme.sizes.thumbSize,
    borderRadius: theme.sizes.thumbSize / 2,
    backgroundColor: theme.colors.white,
    position: 'absolute',
  },
});

export default Switch;
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Animated,
} from 'react-native';
import { Swipeable } from 'react-native-gesture-handler';
import Icon from 'react-native-vector-icons/MaterialIcons';
import theme from '../styles/theme';

/**
 * Swipeable Row Component
 *
 * @param {Object} props - Props for the Swipeable Row.
 * @param {React.ReactNode} props.children - Content of the row.
 * @param {Function} props.onSwipeLeft - Callback for the left swipe action.
 * @param {Function} props.onSwipeRight - Callback for the right swipe action.
 * @param {React.ReactNode} props.leftAction - Custom left action component.
 * @param {React.ReactNode} props.rightAction - Custom right action component.
 * @param {boolean} props.disableSwipe - Disable swipe functionality.
 * @returns {JSX.Element}
 */
const SwipeableRow = ({
  children,
  onSwipeLeft = () => {},
  onSwipeRight = () => {},
  leftAction = null,
  rightAction = null,
  disableSwipe = false,
}) => {
  const renderLeftActions = (progress, dragX) => {
    const scale = dragX.interpolate({
      inputRange: [0, 100],
      outputRange: [0, 1],
      extrapolate: 'clamp',
    });

    return (
      <TouchableOpacity style={[styles.action, styles.leftAction]} onPress={onSwipeLeft}>
        {leftAction || (
          <Animated.View style={{ transform: [{ scale }] }}>
            <Icon name="archive" size={24} color={theme.colors.white} />
            <Text style={styles.actionText}>Archive</Text>
          </Animated.View>
        )}
      </TouchableOpacity>
    );
  };

  const renderRightActions = (progress, dragX) => {
    const scale = dragX.interpolate({
      inputRange: [-100, 0],
      outputRange: [1, 0],
      extrapolate: 'clamp',
    });

    return (
      <TouchableOpacity style={[styles.action, styles.rightAction]} onPress={onSwipeRight}>
        {rightAction || (
          <Animated.View style={{ transform: [{ scale }] }}>
            <Icon name="delete" size={24} color={theme.colors.white} />
            <Text style={styles.actionText}>Delete</Text>
          </Animated.View>
        )}
      </TouchableOpacity>
    );
  };

  if (disableSwipe) {
    return <View style={styles.row}>{children}</View>;
  }

  return (
    <Swipeable
      renderLeftActions={renderLeftActions}
      renderRightActions={renderRightActions}
      overshootLeft={false}
      overshootRight={false}
    >
      <View style={styles.row}>{children}</View>
    </Swipeable>
  );
};

const styles = StyleSheet.create({
  row: {
    backgroundColor: theme.colors.background,
    padding: theme.spacing.md,
    borderRadius: theme.borderRadius.md,
    marginBottom: theme.spacing.sm,
    ...theme.shadows.medium,
  },
  action: {
    justifyContent: 'center',
    alignItems: 'center',
    width: 80,
    height: '100%',
  },
  leftAction: {
    backgroundColor: theme.colors.success,
    borderTopLeftRadius: theme.borderRadius.md,
    borderBottomLeftRadius: theme.borderRadius.md,
  },
  rightAction: {
    backgroundColor: theme.colors.error,
    borderTopRightRadius: theme.borderRadius.md,
    borderBottomRightRadius: theme.borderRadius.md,
  },
  actionText: {
    marginTop: 5,
    color: theme.colors.white,
    fontSize: theme.fontSizes.sm,
  },
});

export default SwipeableRow;
import React from 'react';
import {
  FlatList,
  View,
  Text,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import Typography from './Typography';
import theme from '../styles/theme';
import shadows from '../styles/shadows';

/**
 * List Component
 *
 * @param {Object} props - Props for the List component.
 * @param {Array} props.data - Array of items to render.
 * @param {Function} props.renderItem - Function to render each item.
 * @param {React.ReactNode} [props.ListHeaderComponent] - Optional header component.
 * @param {React.ReactNode} [props.ListFooterComponent] - Optional footer component.
 * @param {React.ReactNode} [props.ListEmptyComponent] - Optional empty state component.
 * @param {boolean} [props.loading=false] - Whether to show a loading indicator.
 * @param {Object} props.style - Additional styles for the list container.
 * @returns {JSX.Element}
 */
const List = ({
  data = [],
  renderItem,
  ListHeaderComponent,
  ListFooterComponent,
  ListEmptyComponent,
  loading = false,
  style,
  ...props
}) => {
  const defaultEmptyComponent = (
    <View style={styles.emptyContainer}>
      <Typography variant="body" color={theme.colors.text}>
        No items available.
      </Typography>
    </View>
  );

  return (
    <View style={[styles.container, shadows.light, style]}>
      {loading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={theme.colors.primary} />
        </View>
      ) : (
        <FlatList
          data={data}
          renderItem={renderItem}
          ListHeaderComponent={ListHeaderComponent}
          ListFooterComponent={ListFooterComponent}
          ListEmptyComponent={ListEmptyComponent || defaultEmptyComponent}
          keyExtractor={(item, index) => index.toString()}
          contentContainerStyle={data.length === 0 && styles.emptyContentContainer}
          {...props}
        />
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
    borderRadius: theme.sizes.borderRadius,
    margin: theme.sizes.spacing,
    overflow: 'hidden',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: theme.sizes.spacing * 2,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: theme.sizes.spacing * 2,
  },
  emptyContentContainer: {
    flexGrow: 1,
    justifyContent: 'center',
  },
});

export default List;
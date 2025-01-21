// Carousel.js
import React, { useState } from 'react';
import {
  View,
  StyleSheet,
  FlatList,
  Dimensions,
  Image,
  Text,
} from 'react-native';
import theme from '../styles/theme';
import Typography from './Typography';

/**
 * Carousel Component
 *
 * @param {Object} props - Props for the Carousel component.
 * @param {Array} props.data - Array of items to display in the carousel.
 * @param {Function} [props.renderItem] - Custom render function for each carousel item.
 * @param {number} [props.interval=3000] - Time interval (in ms) for auto-slide.
 * @param {boolean} [props.autoPlay=false] - Enable auto-slide.
 * @param {boolean} [props.showIndicators=true] - Display navigation dots.
 * @returns {JSX.Element}
 */
const Carousel = ({
  data = [],
  renderItem,
  interval = 3000,
  autoPlay = false,
  showIndicators = true,
}) => {
  const [activeIndex, setActiveIndex] = useState(0);

  const screenWidth = Dimensions.get('window').width;

  const handleScroll = (event) => {
    const scrollPosition = event.nativeEvent.contentOffset.x;
    const newIndex = Math.round(scrollPosition / screenWidth);
    setActiveIndex(newIndex);
  };

  const defaultRenderItem = ({ item }) => (
    <Image source={{ uri: item.image }} style={styles.image} />
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={data}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onScroll={handleScroll}
        renderItem={renderItem || defaultRenderItem}
        keyExtractor={(_, index) => `carousel-item-${index}`}
        style={styles.list}
      />
      {showIndicators && (
        <View style={styles.indicators}>
          {data.map((_, index) => (
            <View
              key={`indicator-${index}`}
              style={[
                styles.indicator,
                index === activeIndex && styles.activeIndicator,
              ]}
            />
          ))}
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '100%',
    alignItems: 'center',
    marginVertical: theme.spacing.lg,
  },
  list: {
    width: '100%',
  },
  image: {
    width: Dimensions.get('window').width,
    height: 200,
    borderRadius: theme.borderRadius.md,
  },
  indicators: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: theme.spacing.sm,
  },
  indicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: theme.colors.inactive,
    marginHorizontal: 4,
  },
  activeIndicator: {
    backgroundColor: theme.colors.primary,
  },
});

export default Carousel;
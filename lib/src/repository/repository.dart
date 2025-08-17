mixin Repository<T> {
  Future<List<String?>?> entries();
  Future<T?> entryFor(String address);
  Future<void> build();
  Future<bool> clear();
  Future<void> close();
}

# Apply the list-interruption extension to the pinned Hoedown source.
# Refuse unknown source layouts rather than silently building without the fix.
def patch_hoedown(root)
  changes = {
    'src/document.h' => [
      ["\tHOEDOWN_EXT_MATH_EXPLICIT = (1 << 13),", "\tHOEDOWN_EXT_MATH_EXPLICIT = (1 << 13),\n\tHOEDOWN_EXT_LAX_SPACING = (1 << 15),"],
      ["\tHOEDOWN_EXT_MATH_EXPLICIT )", "\tHOEDOWN_EXT_MATH_EXPLICIT |\\\n\tHOEDOWN_EXT_LAX_SPACING )"]
    ],
    'src/document.c' => [
      ["\t\tif (is_atxheader(doc, data + i, size - i) ||", "\t\tif (i > 0 && (doc->ext_flags & HOEDOWN_EXT_LAX_SPACING) &&\n\t\t\t(prefix_uli(data + i, size - i) || prefix_oli(data + i, size - i))) {\n\t\t\tend = i;\n\t\t\tbreak;\n\t\t}\n\n\t\tif (is_atxheader(doc, data + i, size - i) ||"]
    ]
  }
  changes.each do |relative, replacements|
    path = File.join(root, relative)
    original = File.read(path)
    modified = original.dup
    replacements.each do |before, after|
      next if modified.include?(after)
      raise "Unexpected Hoedown source: #{relative}" unless modified.scan(before).length == 1
      modified = modified.sub(before, after)
    end
    next if modified == original
    File.chmod(File.stat(path).mode | 0200, path)
    File.write(path, modified)
  end
end

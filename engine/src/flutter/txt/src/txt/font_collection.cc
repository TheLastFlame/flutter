// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "font_collection.h"

#include <algorithm>
#include <list>
#include <memory>
#include <mutex>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>
#include "flutter/fml/logging.h"
#include "flutter/fml/trace_event.h"
#include "txt/platform.h"
#include "txt/text_style.h"

namespace txt {

FontCollection::FontCollection() : enable_font_fallback_(true) {}

FontCollection::~FontCollection() {
  if (skt_collection_) {
    skt_collection_->clearCaches();
  }
}

size_t FontCollection::GetFontManagersCount() const {
  return GetFontManagerOrder().size();
}

void FontCollection::SetupDefaultFontManager(
    uint32_t font_initialization_data) {
  default_font_manager_ = GetDefaultFontManager(font_initialization_data);
  skt_collection_.reset();
}

void FontCollection::SetDefaultFontManager(sk_sp<SkFontMgr> font_manager) {
  default_font_manager_ = std::move(font_manager);
  skt_collection_.reset();
}

void FontCollection::SetAssetFontManager(sk_sp<SkFontMgr> font_manager) {
  asset_font_manager_ = std::move(font_manager);
  skt_collection_.reset();
}

void FontCollection::SetDynamicFontManager(sk_sp<SkFontMgr> font_manager) {
  dynamic_font_manager_ = std::move(font_manager);
  skt_collection_.reset();
}

void FontCollection::SetTestFontManager(sk_sp<SkFontMgr> font_manager) {
  test_font_manager_ = std::move(font_manager);
  skt_collection_.reset();
}

// Return the available font managers in the order they should be queried.
std::vector<sk_sp<SkFontMgr>> FontCollection::GetFontManagerOrder() const {
  std::vector<sk_sp<SkFontMgr>> order;
  if (dynamic_font_manager_) {
    order.push_back(dynamic_font_manager_);
  }
  if (asset_font_manager_) {
    order.push_back(asset_font_manager_);
  }
  if (test_font_manager_) {
    order.push_back(test_font_manager_);
  }
  if (default_font_manager_) {
    order.push_back(default_font_manager_);
  }
  return order;
}

void FontCollection::DisableFontFallback() {
  enable_font_fallback_ = false;
  if (skt_collection_) {
    skt_collection_->disableFontFallback();
  }
}

void FontCollection::ClearFontFamilyCache() {
  if (skt_collection_) {
    skt_collection_->clearCaches();
  }
}

sk_sp<skia::textlayout::FontCollection>
FontCollection::CreateSktFontCollection() {
  if (!skt_collection_) {
    skt_collection_ = sk_make_sp<skia::textlayout::FontCollection>();

    std::vector<SkString> default_font_families;
    for (const std::string& family : GetDefaultFontFamilies()) {
      default_font_families.emplace_back(family);
    }
    skt_collection_->setDefaultFontManager(default_font_manager_,
                                           default_font_families);
    skt_collection_->setAssetFontManager(asset_font_manager_);
    skt_collection_->setDynamicFontManager(dynamic_font_manager_);
    skt_collection_->setTestFontManager(test_font_manager_);
    if (!enable_font_fallback_) {
      skt_collection_->disableFontFallback();
    }
  }

  return skt_collection_;
}

}  // namespace txt

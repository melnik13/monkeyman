use utf8;
package HyperMouse::Schema::Result::ResourceType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

HyperMouse::Schema::Result::ResourceType

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<HyperMouse::Schema::DefaultResult::HyperMouse>

=item * L<HyperMouse::Schema::DefaultResult::I18nRelationships>

=item * L<HyperMouse::Schema::DefaultResult::DeepRelationships>

=item * L<DBIx::Class::Helper::Row::SelfResultSet>

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::EncodedColumn>

=back

=cut

__PACKAGE__->load_components(
  "+HyperMouse::Schema::DefaultResult::HyperMouse",
  "+HyperMouse::Schema::DefaultResult::I18nRelationships",
  "+HyperMouse::Schema::DefaultResult::DeepRelationships",
  "Helper::Row::SelfResultSet",
  "InflateColumn::DateTime",
  "EncodedColumn",
);

=head1 TABLE: C<resource_type>

=cut

__PACKAGE__->table("resource_type");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 valid_since

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 valid_till

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 removed

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 parent_resource_type_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 short_name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "valid_since",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "valid_till",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "removed",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "parent_resource_type_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "short_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 parent_resource_type

Type: belongs_to

Related object: L<HyperMouse::Schema::Result::ResourceType>

=cut

__PACKAGE__->belongs_to(
  "parent_resource_type",
  "HyperMouse::Schema::Result::ResourceType",
  { id => "parent_resource_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 resource_pieces

Type: has_many

Related object: L<HyperMouse::Schema::Result::ResourcePiece>

=cut

__PACKAGE__->has_many(
  "resource_pieces",
  "HyperMouse::Schema::Result::ResourcePiece",
  { "foreign.resource_type_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 resource_type_i18ns

Type: has_many

Related object: L<HyperMouse::Schema::Result::ResourceTypeI18n>

=cut

__PACKAGE__->has_many(
  "resource_type_i18ns",
  "HyperMouse::Schema::Result::ResourceTypeI18n",
  { "foreign.resource_type_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 resource_types

Type: has_many

Related object: L<HyperMouse::Schema::Result::ResourceType>

=cut

__PACKAGE__->has_many(
  "resource_types",
  "HyperMouse::Schema::Result::ResourceType",
  { "foreign.parent_resource_type_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 service_package_sets

Type: has_many

Related object: L<HyperMouse::Schema::Result::ServicePackageSet>

=cut

__PACKAGE__->has_many(
  "service_package_sets",
  "HyperMouse::Schema::Result::ServicePackageSet",
  { "foreign.resource_type_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-07-28 02:37:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Sse+VgaC4O/DK+XgIgWkZg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

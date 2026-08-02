"""Interactive embedded crystal view for the lamaGOET Qt front end."""

from __future__ import annotations

import math
from typing import Sequence

from PySide6.QtCore import QPoint, QPointF, Qt, Signal
from PySide6.QtGui import (
    QColor,
    QImage,
    QLinearGradient,
    QMouseEvent,
    QPainter,
    QPen,
    QPolygonF,
    QRadialGradient,
)
from PySide6.QtWidgets import QWidget

from .crystal import (
    adp_principal_axes,
    Cell,
    DisplayAtom,
    ellipsoid_probability_radius,
    infer_bonds,
)


_COLORS = {
    "H": "#f4f4f4",
    "C": "#454b52",
    "N": "#3158d4",
    "O": "#dc3d35",
    "F": "#4abf68",
    "Cl": "#3dbb58",
    "Br": "#98372e",
    "I": "#7450a7",
    "S": "#e4c62b",
    "P": "#df861f",
    "Fe": "#b86e45",
    "Cu": "#bd7852",
    "Zn": "#888ea1",
}

_SIZES = {
    "H": 0.55,
    "C": 0.78,
    "N": 0.78,
    "O": 0.76,
    "F": 0.72,
    "S": 0.95,
    "P": 0.95,
    "Cl": 0.98,
    "Br": 1.03,
    "I": 1.10,
}


def _circle_directions(steps: int):
    return tuple(
        (
            math.cos(2.0 * math.pi * step / steps),
            math.sin(2.0 * math.pi * step / steps),
        )
        for step in range(steps)
    )


def _ring_samples(steps: int = 48):
    rings = []
    for plane in range(3):
        ring = []
        for step in range(steps + 1):
            angle = 2.0 * math.pi * step / steps
            if plane == 0:
                ring.append((0.0, math.cos(angle), math.sin(angle)))
            elif plane == 1:
                ring.append((math.cos(angle), 0.0, math.sin(angle)))
            else:
                ring.append((math.cos(angle), math.sin(angle), 0.0))
        rings.append(tuple(ring))
    return tuple(rings)


_SILHOUETTE_DIRECTIONS = _circle_directions(72)
_PRINCIPAL_RINGS = _ring_samples()
_SILHOUETTE_DIRECTIONS_FAST = _circle_directions(24)
_PRINCIPAL_RINGS_FAST = _ring_samples(24)


class StructureView(QWidget):
    atom_selected = Signal(object)

    def __init__(self, parent=None):
        super().__init__(parent)
        # Keep a useful drawing area without preventing the surrounding
        # QSplitter from being dragged across most of the main window.
        self.setMinimumSize(360, 360)
        self.setMouseTracking(True)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.atoms: list[DisplayAtom] = []
        self.cell: Cell | None = None
        self.bonds: list[tuple[int, int]] = []
        self.yaw = -0.55
        self.pitch = 0.48
        self.zoom = 1.0
        self.pan = QPointF(0.0, 0.0)
        self._last_mouse = QPoint()
        self._drag_button = Qt.MouseButton.NoButton
        self._projected: list[tuple[float, float, float, float]] = []
        self.selected_index: int | None = None
        self.show_cell = True
        self.show_labels = False
        self.show_ellipsoids = False
        self.ellipsoid_probability = 50.0
        self.projection_mode = "perspective"
        self.depth_cueing = True

    def set_structure(
        self, cell: Cell, atoms: Sequence[DisplayAtom], *, refit: bool = True
    ) -> None:
        self.cell = cell
        self.atoms = list(atoms)
        self.bonds = infer_bonds(self.atoms) if len(self.atoms) <= 1400 else []
        self.selected_index = None
        if refit:
            self.reset_view()
        else:
            self.update()

    def reset_view(self) -> None:
        self.yaw = -0.55
        self.pitch = 0.48
        self.zoom = 1.0
        self.pan = QPointF(0.0, 0.0)
        self.update()

    def selected_atom(self) -> DisplayAtom | None:
        if self.selected_index is None or self.selected_index >= len(self.atoms):
            return None
        return self.atoms[self.selected_index]

    def clear_selection(self) -> None:
        self.selected_index = None
        self.atom_selected.emit(None)
        self.update()

    def select_index(self, index: int) -> None:
        """Select an atom, or toggle it off when it is already selected."""

        if index == self.selected_index:
            self.clear_selection()
            return
        if not 0 <= index < len(self.atoms):
            self.clear_selection()
            return
        self.selected_index = index
        self.atom_selected.emit(self.atoms[index])
        self.update()

    def _center_and_extent(self) -> tuple[tuple[float, float, float], float]:
        if not self.atoms:
            return (0.0, 0.0, 0.0), 1.0
        center = tuple(
            sum(atom.cartesian[axis] for atom in self.atoms) / len(self.atoms)
            for axis in range(3)
        )
        extent = max(
            math.sqrt(
                sum((atom.cartesian[axis] - center[axis]) ** 2 for axis in range(3))
            )
            for atom in self.atoms
        )
        return center, max(extent, 1.0)

    def _rotate(self, point, center):
        x, y, z = (point[index] - center[index] for index in range(3))
        cy, sy = math.cos(self.yaw), math.sin(self.yaw)
        cp, sp = math.cos(self.pitch), math.sin(self.pitch)
        x1 = cy * x + sy * z
        z1 = -sy * x + cy * z
        y2 = cp * y - sp * z1
        z2 = sp * y + cp * z1
        return x1, y2, z2

    def _rotate_vector(self, vector):
        """Apply the view rotation to a direction without translating it."""

        x, y, z = vector
        cy, sy = math.cos(self.yaw), math.sin(self.yaw)
        cp, sp = math.cos(self.pitch), math.sin(self.pitch)
        x1 = cy * x + sy * z
        z1 = -sy * x + cy * z
        return x1, cp * y - sp * z1, sp * y + cp * z1

    def _project(self, point, center, extent):
        x, y, z = self._rotate(point, center)
        usable = max(80.0, min(self.width(), self.height()) - 70.0)
        scale = usable * 0.46 * self.zoom / extent
        perspective = 1.0
        if self.projection_mode == "perspective":
            perspective = max(0.55, min(1.65, 1.0 + z / (extent * 7.0)))
        return (
            self.width() / 2 + self.pan.x() + x * scale * perspective,
            self.height() / 2 + self.pan.y() - y * scale * perspective,
            z,
            scale * perspective,
        )

    def _depth_color(self, color: QColor, z: float, extent: float) -> QColor:
        """Blend distant objects into the background when depth cueing is on."""

        result = QColor(color)
        if not self.depth_cueing:
            return result
        depth = max(0.0, min(1.0, 0.5 + z / (2.4 * extent)))
        fog = QColor("#19232d")
        keep = 0.42 + 0.58 * depth
        result.setRed(round(result.red() * keep + fog.red() * (1.0 - keep)))
        result.setGreen(round(result.green() * keep + fog.green() * (1.0 - keep)))
        result.setBlue(round(result.blue() * keep + fog.blue() * (1.0 - keep)))
        return result

    def _cell_lines(self):
        if not self.cell:
            return []
        a, b, c = self.cell.vectors
        corners = [
            (0.0, 0.0, 0.0),
            a,
            b,
            c,
            tuple(a[i] + b[i] for i in range(3)),
            tuple(a[i] + c[i] for i in range(3)),
            tuple(b[i] + c[i] for i in range(3)),
            tuple(a[i] + b[i] + c[i] for i in range(3)),
        ]
        edges = (
            (0, 1), (0, 2), (0, 3), (1, 4), (1, 5), (2, 4),
            (2, 6), (3, 5), (3, 6), (4, 7), (5, 7), (6, 7),
        )
        return [(corners[left], corners[right]) for left, right in edges]

    @staticmethod
    def _normalise(vector):
        length = math.sqrt(sum(component * component for component in vector))
        if length <= 1.0e-15:
            return (0.0, 0.0, 1.0)
        return tuple(component / length for component in vector)

    @staticmethod
    def _convex_hull(points):
        """Return the screen-space silhouette of a projected convex surface."""

        unique = sorted(set(points))
        if len(unique) <= 2:
            return unique

        def cross(origin, left, right):
            return ((left[0] - origin[0]) * (right[1] - origin[1])) - (
                (left[1] - origin[1]) * (right[0] - origin[0])
            )

        lower = []
        for point in unique:
            while len(lower) >= 2 and cross(lower[-2], lower[-1], point) <= 0.0:
                lower.pop()
            lower.append(point)
        upper = []
        for point in reversed(unique):
            while len(upper) >= 2 and cross(upper[-2], upper[-1], point) <= 0.0:
                upper.pop()
            upper.append(point)
        return lower[:-1] + upper[:-1]

    @staticmethod
    def _lit_color(color: QColor, normal) -> QColor:
        """MoleCool-style fixed lighting for a surface normal in view space."""

        light = (-0.36, 0.48, 0.80)
        halfway = (-0.19, 0.25, 0.95)
        diffuse = max(0.0, sum(normal[index] * light[index] for index in range(3)))
        specular = max(
            0.0, sum(normal[index] * halfway[index] for index in range(3))
        ) ** 28
        brightness = 0.30 + 0.76 * diffuse
        shine = 0.34 * specular
        return QColor(
            min(255, round(color.red() * brightness + 255.0 * shine)),
            min(255, round(color.green() * brightness + 255.0 * shine)),
            min(255, round(color.blue() * brightness + 255.0 * shine)),
            color.alpha(),
        )

    @staticmethod
    def _inverse_3x3(matrix):
        a, b, c = matrix[0]
        d, e, f = matrix[1]
        g, h, i = matrix[2]
        determinant = (
            a * (e * i - f * h)
            - b * (d * i - f * g)
            + c * (d * h - e * g)
        )
        if abs(determinant) <= 1.0e-18:
            return None
        inverse = 1.0 / determinant
        return (
            (
                (e * i - f * h) * inverse,
                (c * h - b * i) * inverse,
                (b * f - c * e) * inverse,
            ),
            (
                (f * g - d * i) * inverse,
                (a * i - c * g) * inverse,
                (c * d - a * f) * inverse,
            ),
            (
                (d * h - e * g) * inverse,
                (b * g - a * h) * inverse,
                (a * e - b * d) * inverse,
            ),
        )

    def _ellipsoid_axes(self, atom: DisplayAtom):
        if atom.u_cartesian:
            tensor = atom.u_cartesian
        elif atom.u_iso is not None and atom.u_iso > 0.0:
            tensor = (atom.u_iso, atom.u_iso, atom.u_iso, 0.0, 0.0, 0.0)
        else:
            return None
        decomposition = adp_principal_axes(tensor)
        if decomposition is None:
            return None
        eigenvalues, axes = decomposition
        probability_scale = ellipsoid_probability_radius(self.ellipsoid_probability)
        lengths = tuple(
            probability_scale * math.sqrt(value) for value in eigenvalues
        )
        return lengths, axes

    def _draw_ellipsoid(
        self, painter, atom, index, color, center, extent
    ) -> float | None:
        """Draw a lit, depth-aware probability ellipsoid and principal rings.

        MoleCoolQt renders a unit OpenGL sphere after rotating and scaling it by
        the eigenvectors and eigenvalues of Ucart.  This uses the same geometry
        and probability scaling, rendered in software so it also works on
        systems where an OpenGL compatibility profile is unavailable.
        """

        principal = self._ellipsoid_axes(atom)
        if principal is None:
            return None
        lengths, axes = principal
        view_axes = tuple(self._rotate_vector(axis) for axis in axes)
        point_columns = tuple(
            tuple(lengths[axis] * component for component in view_axes[axis])
            for axis in range(3)
        )
        normal_columns = tuple(
            tuple(component / lengths[axis] for component in view_axes[axis])
            for axis in range(3)
        )
        atom_view = self._rotate(atom.cartesian, center)
        usable = max(80.0, min(self.width(), self.height()) - 70.0)
        fit_scale = usable * 0.46 * self.zoom / extent
        screen_center_x = self.width() / 2 + self.pan.x()
        screen_center_y = self.height() / 2 + self.pan.y()
        p0, p1, p2 = point_columns
        n0, n1, n2 = normal_columns

        def vertex(unit):
            unit_x, unit_y, unit_z = unit
            displacement_x = p0[0] * unit_x + p1[0] * unit_y + p2[0] * unit_z
            displacement_y = p0[1] * unit_x + p1[1] * unit_y + p2[1] * unit_z
            displacement_z = p0[2] * unit_x + p1[2] * unit_y + p2[2] * unit_z
            view_x = atom_view[0] + displacement_x
            view_y = atom_view[1] + displacement_y
            view_z = atom_view[2] + displacement_z
            perspective = 1.0
            if self.projection_mode == "perspective":
                perspective = max(
                    0.55, min(1.65, 1.0 + view_z / (extent * 7.0))
                )
            screen_scale = fit_scale * perspective
            normal_x = n0[0] * unit_x + n1[0] * unit_y + n2[0] * unit_z
            normal_y = n0[1] * unit_x + n1[1] * unit_y + n2[1] * unit_z
            normal_z = n0[2] * unit_x + n1[2] * unit_y + n2[2] * unit_z
            normal_length = math.sqrt(
                normal_x * normal_x
                + normal_y * normal_y
                + normal_z * normal_z
            )
            return (
                (
                    screen_center_x + view_x * screen_scale,
                    screen_center_y - view_y * screen_scale,
                    view_z,
                    screen_scale,
                ),
                (
                    normal_x / normal_length,
                    normal_y / normal_length,
                    normal_z / normal_length,
                ),
            )

        interactive = self._drag_button != Qt.MouseButton.NoButton
        silhouette_directions = (
            _SILHOUETTE_DIRECTIONS_FAST
            if interactive
            else _SILHOUETTE_DIRECTIONS
        )
        ring_units = _PRINCIPAL_RINGS_FAST if interactive else _PRINCIPAL_RINGS
        vertices = []
        for direction_x, direction_y in silhouette_directions:
            weights = (
                p0[0] * direction_x + p0[1] * direction_y,
                p1[0] * direction_x + p1[1] * direction_y,
                p2[0] * direction_x + p2[1] * direction_y,
            )
            weight_length = math.sqrt(sum(value * value for value in weights))
            vertices.append(
                vertex(tuple(value / weight_length for value in weights))
            )
        projected_points = [(item[0][0], item[0][1]) for item in vertices]
        hull = self._convex_hull(projected_points)

        # Render the same scaled-sphere surface as MoleCoolQt, but solve the
        # ellipsoid equation per screen pixel.  This provides smoothly varying
        # normals (the equivalent of GL_SMOOTH) instead of visibly faceted
        # QPainter triangles.
        shape = tuple(
            tuple(
                sum(
                    lengths[axis] ** 2
                    * view_axes[axis][row]
                    * view_axes[axis][column]
                    for axis in range(3)
                )
                for column in range(3)
            )
            for row in range(3)
        )
        inverse_shape = self._inverse_3x3(shape)
        atom_x, atom_y, atom_z, pixel_scale = self._project(
            atom.cartesian, center, extent
        )
        if inverse_shape is None or pixel_scale <= 0.0:
            return None
        left = max(0, math.floor(min(point[0] for point in projected_points)) - 1)
        top = max(0, math.floor(min(point[1] for point in projected_points)) - 1)
        right = min(
            self.width() - 1,
            math.ceil(max(point[0] for point in projected_points)) + 1,
        )
        bottom = min(
            self.height() - 1,
            math.ceil(max(point[1] for point in projected_points)) + 1,
        )
        image_width = right - left + 1
        image_height = bottom - top + 1
        if interactive and len(hull) >= 3:
            # Keep rotation and panning fluid.  The exact surface silhouette and
            # rings still move in 3-D; only the expensive per-pixel normal pass
            # is temporarily replaced by a smooth lit fill until mouse release.
            apparent_radius = max(
                math.hypot(x - atom_x, y - atom_y) for x, y in projected_points
            )
            highlight = QColor(color).lighter(195)
            shadow = QColor(color).darker(180)
            gradient = QRadialGradient(
                QPointF(
                    atom_x - apparent_radius * 0.30,
                    atom_y - apparent_radius * 0.34,
                ),
                apparent_radius * 1.45,
            )
            gradient.setColorAt(0.0, highlight)
            gradient.setColorAt(0.48, color)
            gradient.setColorAt(1.0, shadow)
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(gradient)
            painter.drawPolygon(QPolygonF([QPointF(*point) for point in hull]))
        elif image_width > 0 and image_height > 0:
            image = QImage(
                image_width,
                image_height,
                QImage.Format.Format_RGBA8888,
            )
            image.fill(Qt.GlobalColor.transparent)
            pixels = image.bits()
            stride = image.bytesPerLine()
            q00, q01, q02 = inverse_shape[0]
            _, q11, q12 = inverse_shape[1]
            _, _, q22 = inverse_shape[2]
            red, green, blue = color.red(), color.green(), color.blue()
            fog_red, fog_green, fog_blue = 25, 35, 45
            for image_y in range(image_height):
                view_y = -(top + image_y + 0.5 - atom_y) / pixel_scale
                for image_x in range(image_width):
                    view_x = (left + image_x + 0.5 - atom_x) / pixel_scale
                    linear = q02 * view_x + q12 * view_y
                    constant = (
                        q00 * view_x * view_x
                        + 2.0 * q01 * view_x * view_y
                        + q11 * view_y * view_y
                        - 1.0
                    )
                    discriminant = linear * linear - q22 * constant
                    if discriminant < 0.0:
                        continue
                    view_z = (-linear + math.sqrt(discriminant)) / q22
                    normal_x = q00 * view_x + q01 * view_y + q02 * view_z
                    normal_y = q01 * view_x + q11 * view_y + q12 * view_z
                    normal_z = q02 * view_x + q12 * view_y + q22 * view_z
                    normal_length = math.sqrt(
                        normal_x * normal_x
                        + normal_y * normal_y
                        + normal_z * normal_z
                    )
                    normal_x /= normal_length
                    normal_y /= normal_length
                    normal_z /= normal_length
                    diffuse = max(
                        0.0,
                        -0.36 * normal_x + 0.48 * normal_y + 0.80 * normal_z,
                    )
                    specular = max(
                        0.0,
                        -0.19 * normal_x + 0.25 * normal_y + 0.95 * normal_z,
                    ) ** 28
                    brightness = 0.30 + 0.76 * diffuse
                    shine = 86.7 * specular
                    if self.depth_cueing:
                        depth = max(
                            0.0,
                            min(1.0, 0.5 + (atom_z + view_z) / (2.4 * extent)),
                        )
                        keep = 0.42 + 0.58 * depth
                        surface_red = red * keep + fog_red * (1.0 - keep)
                        surface_green = green * keep + fog_green * (1.0 - keep)
                        surface_blue = blue * keep + fog_blue * (1.0 - keep)
                    else:
                        surface_red, surface_green, surface_blue = red, green, blue
                    offset = image_y * stride + image_x * 4
                    pixels[offset] = min(255, round(surface_red * brightness + shine))
                    pixels[offset + 1] = min(
                        255, round(surface_green * brightness + shine)
                    )
                    pixels[offset + 2] = min(
                        255, round(surface_blue * brightness + shine)
                    )
                    pixels[offset + 3] = 255
            painter.drawImage(left, top, image)

        ring_color = QColor("#171b20")
        ring_color.setAlpha(220)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.setPen(QPen(ring_color, 1.55, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        for units in ring_units:
            ring = [vertex(unit) for unit in units]
            visible_run = []
            for left, right in zip(ring, ring[1:]):
                if (left[1][2] + right[1][2]) / 2.0 <= 0.01:
                    if len(visible_run) >= 2:
                        painter.drawPolyline(QPolygonF(visible_run))
                    visible_run = []
                    continue
                if not visible_run:
                    visible_run.append(QPointF(left[0][0], left[0][1]))
                visible_run.append(QPointF(right[0][0], right[0][1]))
            if len(visible_run) >= 2:
                painter.drawPolyline(QPolygonF(visible_run))

        if len(hull) >= 3:
            if index == self.selected_index:
                painter.setPen(QPen(QColor("#ffd35a"), 3.0))
            else:
                outline = QColor(color).darker(185)
                painter.setPen(QPen(outline, 1.35))
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawPolygon(QPolygonF([QPointF(*point) for point in hull]))

        return max(
            (math.hypot(x - atom_x, y - atom_y) for x, y in projected_points),
            default=1.0,
        )

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        background = QLinearGradient(0, 0, 0, self.height())
        background.setColorAt(0, QColor("#111821"))
        background.setColorAt(1, QColor("#202b36"))
        painter.fillRect(self.rect(), background)
        if not self.atoms:
            painter.setPen(QColor("#b7c4cf"))
            painter.drawText(
                self.rect(),
                Qt.AlignmentFlag.AlignCenter,
                "Open a CIF to inspect and grow its structure",
            )
            painter.end()
            return

        center, extent = self._center_and_extent()
        self._projected = [
            self._project(atom.cartesian, center, extent) for atom in self.atoms
        ]

        if self.show_cell and self.cell:
            painter.setPen(QPen(QColor(118, 162, 198, 150), 1.2, Qt.PenStyle.DashLine))
            for start, end in self._cell_lines():
                x1, y1, _, _ = self._project(start, center, extent)
                x2, y2, _, _ = self._project(end, center, extent)
                painter.drawLine(QPointF(x1, y1), QPointF(x2, y2))

        for left, right in self.bonds:
            x1, y1, z1, _ = self._projected[left]
            x2, y2, z2, _ = self._projected[right]
            midpoint = QPointF((x1 + x2) / 2.0, (y1 + y2) / 2.0)
            left_color = self._depth_color(
                QColor(_COLORS.get(self.atoms[left].element, "#b286c7")), z1, extent
            ).lighter(125)
            right_color = self._depth_color(
                QColor(_COLORS.get(self.atoms[right].element, "#b286c7")), z2, extent
            ).lighter(125)
            painter.setPen(QPen(left_color, 5.0, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
            painter.drawLine(QPointF(x1, y1), midpoint)
            painter.setPen(QPen(right_color, 5.0, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
            painter.drawLine(midpoint, QPointF(x2, y2))

        order = sorted(range(len(self.atoms)), key=lambda index: self._projected[index][2])
        for index in order:
            atom = self.atoms[index]
            x, y, z, scale = self._projected[index]
            radius = max(4.0, min(18.0, _SIZES.get(atom.element, 0.85) * scale * 0.12))
            color = self._depth_color(
                QColor(_COLORS.get(atom.element, "#b286c7")), z, extent
            )
            ellipsoid_drawn = False
            label_extent = radius
            if self.show_ellipsoids and (atom.u_aniso or atom.u_iso is not None):
                rendered_extent = self._draw_ellipsoid(
                    painter, atom, index, color, center, extent
                )
                if rendered_extent is not None:
                    label_extent = rendered_extent
                    ellipsoid_drawn = True
            if not ellipsoid_drawn:
                if index == self.selected_index:
                    painter.setPen(QPen(QColor("#ffd35a"), 3.0))
                else:
                    painter.setPen(QPen(color.lighter(145), 1.0))
                highlight = QColor(color).lighter(190)
                shadow = QColor(color).darker(165)
                sphere_gradient = QRadialGradient(
                    QPointF(x - radius * 0.30, y - radius * 0.34), radius * 1.45
                )
                sphere_gradient.setColorAt(0.0, highlight)
                sphere_gradient.setColorAt(0.50, color)
                sphere_gradient.setColorAt(1.0, shadow)
                painter.setBrush(sphere_gradient)
                painter.drawEllipse(QPointF(x, y), radius, radius)
            if self.show_labels:
                painter.setPen(QColor("#edf3f7"))
                painter.drawText(
                    QPointF(x + label_extent + 2, y - label_extent), atom.label
                )
        painter.end()

    def mousePressEvent(self, event: QMouseEvent) -> None:
        self._last_mouse = event.position().toPoint()
        self._drag_button = event.button()
        if event.button() == Qt.MouseButton.LeftButton and self._projected:
            closest = None
            closest_distance = 15.0
            for index, (x, y, _, _) in enumerate(self._projected):
                distance = math.hypot(event.position().x() - x, event.position().y() - y)
                if distance < closest_distance:
                    closest = index
                    closest_distance = distance
            if closest is not None:
                self.select_index(closest)

    def keyPressEvent(self, event) -> None:
        if event.key() == Qt.Key.Key_Escape:
            self.clear_selection()
            event.accept()
            return
        super().keyPressEvent(event)

    def mouseMoveEvent(self, event: QMouseEvent) -> None:
        current = event.position().toPoint()
        delta = current - self._last_mouse
        if event.buttons() & Qt.MouseButton.LeftButton:
            self.yaw += delta.x() * 0.009
            self.pitch = max(-1.5, min(1.5, self.pitch + delta.y() * 0.009))
            self.update()
        elif event.buttons() & (
            Qt.MouseButton.MiddleButton | Qt.MouseButton.RightButton
        ):
            self.pan += QPointF(delta)
            self.update()
        self._last_mouse = current

    def mouseReleaseEvent(self, event: QMouseEvent) -> None:
        self._drag_button = Qt.MouseButton.NoButton
        # Replace the lightweight interactive surface with fully smooth
        # MoleCool-style normal lighting at the final orientation.
        self.update()

    def wheelEvent(self, event) -> None:
        self.zoom = max(0.15, min(8.0, self.zoom * (1.15 ** (event.angleDelta().y() / 120))))
        self.update()
